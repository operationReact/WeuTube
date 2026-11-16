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
