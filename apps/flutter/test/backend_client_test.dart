import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:weutube/backend_client.dart';

void main() {
  test('Cognito login stores token in memory and authorizes creator requests', () async {
    final paths=<String>[];
    final client=MockClient((req) async {
      paths.add(req.url.path);
      if(req.url.path.endsWith('/sign-in')) {
        final request=jsonDecode(req.body) as Map<String,dynamic>;
        expect(request['email'],'test@example.com');
        return http.Response(jsonEncode({'status':'SIGNED_IN',
          'accessToken':'real-access','refreshToken':'refresh-access'}),200);
      }
      expect(req.headers['Authorization'],'Bearer real-access');
      return http.Response(jsonEncode({'videos':2,'drafts':1,'pendingReview':0,'published':1,
        'views':null,'subscribers':null,'analyticsStatus':'NOT_CONNECTED'}),200);
    });
    final api=WeuTubeApi(client:client);
    await api.login('test@example.com','correct-password');
    expect(api.signedIn,isTrue);
    final summary=await api.dashboard();
    expect(summary['videos'],2);
    expect(paths,['/api/public/auth/sign-in','/api/creator/dashboard']);
    api.clear();
    expect(api.signedIn,isFalse);
    api.dispose();
  });
  test('Google callback follows the exact official web origin', () {
    const defaultRedirect = 'https://weutube.com/auth.html';
    expect(googleWebCallbackForOrigin(defaultRedirect,
      Uri.parse('https://weutube.com/create'), isWeb:true),
      'https://weutube.com/auth.html');
    expect(googleWebCallbackForOrigin(defaultRedirect,
      Uri.parse('https://www.weutube.com/sign-in'), isWeb:true),
      'https://www.weutube.com/auth.html');
    expect(googleWebCallbackForOrigin(defaultRedirect,
      Uri.parse('https://attacker.weutube.com/'), isWeb:true),
      defaultRedirect);
    expect(googleWebCallbackForOrigin(defaultRedirect,
      Uri.parse('http://weutube.com/'), isWeb:true),
      defaultRedirect);
    expect(googleWebCallbackForOrigin(defaultRedirect,
      Uri.parse('https://www.weutube.com/'), isWeb:false),
      defaultRedirect);
  });

  test('Google auth is safely unavailable until Cognito identity provider is enabled', () async {
    final api=WeuTubeApi(client:MockClient((req) async =>
      http.Response(jsonEncode({'enabled':false}),200)));
    await expectLater(api.loginWithGoogle(), throwsA(isA<ApiFailure>()));
    expect(api.signedIn, isFalse);
    api.dispose();
  });

  test('Google auth uses state and PKCE before accepting Cognito token', () async {
    String? expectedState;
    final paths=<String>[];
    final client=MockClient((req) async {
      paths.add(req.url.path);
      if(req.url.path.endsWith('google-config')) {
        return http.Response(jsonEncode({
          'enabled':true,
          'hostedUiDomain':'https://example.auth.ap-south-1.amazoncognito.com',
          'clientId':'public-cognito-client',
          'nativeRedirectUri':'weutube://auth-callback',
          'webRedirectUri':'https://weutube.com/auth.html',
        }),200);
      }
      expect(req.url.path, '/oauth2/token');
      expect(req.bodyFields['code_verifier'], isNotEmpty);
      expect(req.bodyFields['grant_type'], 'authorization_code');
      return http.Response(jsonEncode({
        'access_token':'issued-google-cognito-access',
        'id_token':'issued-google-cognito-id',
        'refresh_token':'issued-google-cognito-refresh',
      }),200);
    });
    final api=WeuTubeApi(client:client);
    await api.loginWithGoogle(authorize:(url, scheme) async {
      final uri=Uri.parse(url);
      expect(uri.queryParameters['identity_provider'],'Google');
      expect(uri.queryParameters['code_challenge_method'],'S256');
      expect(uri.queryParameters['code_challenge'],isNotEmpty);
      expect(uri.queryParameters['redirect_uri'],'weutube://auth-callback');
      expectedState=uri.queryParameters['state'];
      return 'weutube://auth-callback?code=test-code&state=$expectedState';
    });
    expect(api.signedIn,isTrue);
    expect(api.accessToken,'issued-google-cognito-access');
    expect(paths,['/api/public/auth/google-config','/oauth2/token']);
    api.dispose();
  });

  test('Mismatched Google callback state is rejected without token exchange', () async {
    var tokenCalls=0;
    final api=WeuTubeApi(client:MockClient((req) async {
      if(req.url.path.endsWith('/oauth2/token')) tokenCalls++;
      return http.Response(jsonEncode({
        'enabled':true,
        'hostedUiDomain':'https://example.auth.ap-south-1.amazoncognito.com',
        'clientId':'public-client',
        'nativeRedirectUri':'weutube://auth-callback',
        'webRedirectUri':'https://weutube.com/auth.html',
      }),200);
    }));
    await expectLater(api.loginWithGoogle(authorize:(_,_scheme) async =>
      'weutube://auth-callback?code=code&state=attacker'),throwsA(isA<ApiFailure>()));
    expect(tokenCalls,0);
    expect(api.signedIn,isFalse);
    api.dispose();
  });

  test('Registration never assumes sign-in', () async {
    final api=WeuTubeApi(client:MockClient((req) async =>
      http.Response(jsonEncode({'status':'CONFIRMATION_REQUIRED'}),200)));
    final result=await api.signUp('Creator','creator@example.com','correct-password');
    expect(result['status'],'CONFIRMATION_REQUIRED');
    expect(api.signedIn,isFalse);
    api.dispose();
  });
  test('Failed sign-in does not create a session', () async {
    final api=WeuTubeApi(client:MockClient((req) async =>
      http.Response(jsonEncode({'message':'unauthorized'}),401)));
    await expectLater(api.login('test@example.com','bad'),throwsA(isA<ApiFailure>()));
    expect(api.signedIn,isFalse);
    api.dispose();
  });
}
