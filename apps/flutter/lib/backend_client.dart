import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'dart:typed_data';
import 'upload_chunk_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'youtube_upload_rules.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

/// A shared HTTPS backend for Android, iOS and Flutter web.
const apiOrigin = String.fromEnvironment('WEUTUBE_API_ORIGIN',
  defaultValue: 'https://api.weutube.com');

class ApiFailure implements Exception {
  final String message;
  final int? code;
  const ApiFailure(this.message, [this.code]);
  @override
  String toString() => message;
}

/// No secrets are persisted to insecure local storage.
/// A new app session requires sign-in again.
class WeuTubeApi {
  WeuTubeApi({http.Client? client}): _client = client ?? http.Client();
  final http.Client _client;
  String? accessToken;
  String? refreshToken;
  bool get signedIn => accessToken != null;
  // UI-only flag. Every admin API independently validates Cognito group membership.
  bool get showAdminMenu {
    try {
      final parts=accessToken?.split('.');
      if(parts==null || parts.length!=3) return false;
      final payload=jsonDecode(utf8.decode(base64Url.decode(
        base64Url.normalize(parts[1])))) as Map<String,dynamic>;
      final groups=payload['cognito:groups'];
      return groups is List && groups.contains('weutube-admin');
    } catch (_) { return false; }
  }
  Uri uri(String path) => Uri.parse(apiOrigin + path);

  Future<dynamic> call(String method, String path,
      {Map<String, dynamic>? data, bool auth = true, bool retry = true}) async {
    final headers = <String,String>{'Accept':'application/json'};
    if(data != null) headers['Content-Type'] = 'application/json';
    if(auth) {
      if(accessToken == null) throw const ApiFailure('Sign in to continue.',401);
      headers['Authorization'] = 'Bearer ' + accessToken!;
    }
    http.Response response;
    try {
      final request = http.Request(method,uri(path))..headers.addAll(headers);
      if(data != null) request.body = jsonEncode(data);
      response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 25)));
    } catch (_) {
      throw const ApiFailure('WeuTube API unreachable. Check your internet connection.');
    }
    if(response.statusCode == 401 && auth && retry && refreshToken != null) {
      try {
        await refresh();
        return await call(method,path,data:data,auth:auth,retry:false);
      } catch (_) {
        clear();
        throw const ApiFailure('Session expired. Sign in again.',401);
      }
    }
    final status = response.statusCode;
    if(status < 200 || status >= 300) {
      if(status==401) throw const ApiFailure(
        'Your Cognito session is invalid or expired. Sign in again.',401);
      if(status==403) {
        final kind=response.headers['x-weutube-auth-status'];
        if(kind=='AUTHORIZATION_DENIED') {
          throw const ApiFailure(
            'You are signed in, but the server denied access to this '
            'specific operation (HTTP 403).',403);
        }
        throw const ApiFailure(
          'The API returned HTTP 403 without confirming that your token '
          'was accepted. This needs backend authentication diagnosis.',403);
      }
      if(status==404) throw const ApiFailure('Account or requested item not found.',404);
      if(status==409) throw const ApiFailure('Action conflicts with the current status.',409);
      if(status==412 || status==428) throw ApiFailure('Verified private video required.',status);
      if(status==429) throw const ApiFailure('Too many requests; retry later.',429);
      throw ApiFailure('Request failed. HTTP ' + status.toString(),status);
    }
    if(response.body.isEmpty) return <String,dynamic>{};
    try { return jsonDecode(response.body); }
    catch (_) { throw const ApiFailure('Unexpected API response.'); }
  }
  Map<String,dynamic> asMap(dynamic value) {
    if(value is Map<String,dynamic>) return value;
    throw const ApiFailure('Unexpected API response.');
  }
  Future<Map<String,dynamic>> signUp(String name,String email,String password) async =>
    asMap(await call('POST','/api/public/auth/sign-up',auth:false,
      data:{'displayName':name,'email':email,'password':password}));
  Future<void> confirm(String email,String code) async =>
    call('POST','/api/public/auth/confirm',auth:false,data:{'email':email,'code':code});
  Future<void> resend(String email) async =>
    call('POST','/api/public/auth/resend-code',auth:false,data:{'email':email});
  /// Cognito Hosted UI authorization-code + PKCE, federated through Google.
  /// Uses the *same* Cognito user pool and JWTs as password login. The Google
  /// identity provider is separate from the YouTube channel OAuth connection.
  /// Never embed an OAuth client secret in the mobile app.
  Future<Map<String,dynamic>> loginWithGoogle({
    Future<String> Function(String authorizationUrl, String callbackScheme)? authorize,
  }) async {
    final config = asMap(await call(
      'GET', '/api/public/auth/google-config', auth: false));
    if(config['enabled'] != true) {
      throw const ApiFailure('Google sign-in requires the WeuTube Google '
        'identity provider to be configured. Use email sign-in for now.', 503);
    }
    final domain = config['hostedUiDomain']?.toString() ?? '';
    final clientId = config['clientId']?.toString() ?? '';
    final redirect = kIsWeb
      ? config['webRedirectUri']?.toString() ?? ''
      : config['nativeRedirectUri']?.toString() ?? '';
    final base = Uri.tryParse(domain);
    final redirectUri = Uri.tryParse(redirect);
    if (base == null || base.scheme != 'https' || base.host.isEmpty ||
        base.userInfo.isNotEmpty || clientId.isEmpty || redirectUri == null ||
        redirectUri.scheme.isEmpty) {
      throw const ApiFailure('Google sign-in configuration is incomplete.', 503);
    }
    String randomUrlSafe(int length) {
      final rng = math.Random.secure();
      return base64Url.encode(
        List<int>.generate(length, (_) => rng.nextInt(256)))
        .replaceAll('=', '');
    }
    final state = randomUrlSafe(32);
    final verifier = randomUrlSafe(48);
    final challenge = base64Url.encode(
      sha256.convert(utf8.encode(verifier)).bytes).replaceAll('=', '');
    final url = base.resolve('oauth2/authorize').replace(queryParameters: {
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': redirect,
      'scope': 'openid email profile',
      'identity_provider': 'Google',
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
      'state': state,
    });
    final callback = await (authorize != null
      ? authorize(url.toString(), redirectUri.scheme)
      : FlutterWebAuth2.authenticate(url: url.toString(),
          callbackUrlScheme: redirectUri.scheme));
    final params = Uri.parse(callback).queryParameters;
    if (params['state'] != state) {
      throw const ApiFailure('Google sign-in could not be verified. Try again.');
    }
    if (params['error'] != null) {
      throw const ApiFailure('Google sign-in was cancelled or declined.');
    }
    final code = params['code'];
    if (code == null || code.isEmpty) {
      throw const ApiFailure('Google sign-in did not return an authorization code.');
    }
    final response = await _client.post(base.resolve('oauth2/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'client_id': clientId,
        'code': code,
        'redirect_uri': redirect,
        'code_verifier': verifier,
      }).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw const ApiFailure(
        'Google authorization was not completed by Cognito. Please retry.');
    }
    final tokenBody = jsonDecode(response.body);
    if (tokenBody is! Map<String,dynamic> ||
        tokenBody['id_token'] is! String ||
        tokenBody['access_token'] is! String) {
      throw const ApiFailure('Invalid identity-provider token response.');
    }
    final result = <String,dynamic>{
      'status': 'SIGNED_IN',
      'accessToken': tokenBody['access_token'],
      'idToken': tokenBody['id_token'],
      if (tokenBody['refresh_token'] is String)
        'refreshToken': tokenBody['refresh_token'],
    };
    receive(result);
    return result;
  }

  Future<Map<String,dynamic>> login(String email,String password) async {
    final result=asMap(await call('POST','/api/public/auth/sign-in',auth:false,
      data:{'email':email,'password':password}));
    if(result['status']=='SIGNED_IN') receive(result);
    return result;
  }
  Future<Map<String,dynamic>> completeMfa(String email,String session,String challenge,String code) async {
    final result=asMap(await call('POST','/api/public/auth/confirm-mfa',auth:false,
      data:{'email':email,'session':session,'challenge':challenge,'code':code}));
    if(result['status']=='SIGNED_IN') receive(result);
    return result;
  }
  Future<void> forgot(String email) async =>
    call('POST','/api/public/auth/forgot-password',auth:false,data:{'email':email});
  Future<void> reset(String email,String code,String password) async =>
    call('POST','/api/public/auth/reset-password',auth:false,
      data:{'email':email,'code':code,'newPassword':password});
  void receive(Map<String,dynamic> result) {
    final token=result['accessToken'];
    if(token is! String || token.isEmpty) throw const ApiFailure('No access token returned.');
    accessToken=token;
    if(result['refreshToken'] is String) refreshToken=result['refreshToken'] as String;
  }
  Future<void> refresh() async {
    if(refreshToken==null) throw const ApiFailure('Sign in again.');
    receive(asMap(await call('POST','/api/public/auth/refresh',auth:false,
      data:{'refreshToken':refreshToken})));
  }
  void clear() {accessToken=null;refreshToken=null;}
  Future<void> logout() async {
    try {if(signedIn) await call('POST','/api/auth/sign-out',retry:false);}
    finally {clear();}
  }
  /// Validates the Cognito bearer token independently of YouTube grants.
  /// An authenticated account with no channel should receive 200, not 403.
  Future<Map<String,dynamic>> creatorSession() async =>
    asMap(await call('GET','/api/creator/session'));
  Future<Map<String,dynamic>> dashboard() async => asMap(await call('GET','/api/creator/dashboard'));
  Future<List<Map<String,dynamic>>> grantedChannels() => list('/api/creator/channels');
  Future<Map<String,dynamic>> activateCreatorChannel() async =>
    asMap(await call('POST','/api/creator/channels/activate'));
  Future<List<Map<String,dynamic>>> videos() => list('/api/creator/videos');
  Future<Map<String,dynamic>> video(String id) async =>
    asMap(await call('GET','/api/creator/videos/'+Uri.encodeComponent(id)));
  Future<Map<String,dynamic>> createDraft(String title) async =>
    asMap(await call('POST','/api/creator/videos/drafts',data:{'title':title}));
  Future<Map<String,dynamic>> updateDraftMetadata(String id,String title,
      String description,String category) async =>
    asMap(await call('PATCH','/api/creator/videos/drafts/'+
      Uri.encodeComponent(id)+'/metadata',
      data:{'title':title,'description':description,'category':category}));
  Future<Map<String,dynamic>> renameDraft(String id,String title) async =>
    asMap(await call('PATCH','/api/creator/videos/drafts/'+Uri.encodeComponent(id),data:{'title':title}));
  Future<void> deleteDraft(String id) async =>
    call('DELETE','/api/creator/videos/drafts/'+Uri.encodeComponent(id));
  Future<Map<String,dynamic>> profile() async => asMap(await call('GET','/api/creator/account'));
  Future<Map<String,dynamic>> updateProfile(String name) async =>
    asMap(await call('PATCH','/api/creator/account',data:{'displayName':name}));
  Future<Map<String,dynamic>> wallet() async => asMap(await call('GET','/api/creator/wallet'));
  Future<List<Map<String,dynamic>>> withdrawals() => list('/api/creator/wallet/withdrawals');
  Future<Map<String,dynamic>> analytics() async => asMap(await call('GET','/api/creator/analytics'));
  Future<List<Map<String,dynamic>>> notifications() => list('/api/creator/notifications');
  Future<List<Map<String,dynamic>>> list(String path) async {
    final result=await call('GET',path);
    return (result is List ? result : <dynamic>[])
      .whereType<Map<String,dynamic>>().toList();
  }
  Future<Map<String,dynamic>> upload(String draftId,String channelId,
      Uint8List bytes,String filename) async {
    if(bytes.isEmpty || bytes.length>20*1024*1024)
      throw const ApiFailure('Test uploads must be under 20 MB.');
    if(!signedIn) throw const ApiFailure('Sign in first.');
    final request=http.MultipartRequest('POST',
      uri('/api/creator/videos/'+Uri.encodeComponent(draftId)+'/private-upload'))
      ..headers['Authorization']='Bearer '+accessToken!
      ..fields['channelId']=channelId
      ..files.add(http.MultipartFile.fromBytes('file',bytes,filename:filename,
        contentType: MediaType.parse(
          filename.toLowerCase().endsWith('.mp4') ? 'video/mp4' :
          filename.toLowerCase().endsWith('.mov') ? 'video/quicktime' :
          filename.toLowerCase().endsWith('.webm') ? 'video/webm' :
          filename.toLowerCase().endsWith('.mkv') ? 'video/x-matroska' :
          'video/mp4')));
    http.Response response;
    try {
      response=await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(minutes: 4)));
    } catch (_) {throw const ApiFailure('Upload interrupted. Check video status before retry.');}
    if(response.statusCode!=200 && response.statusCode!=201)
      throw ApiFailure('Upload failed. HTTP '+response.statusCode.toString()+
        '. Confirm channel permission before retrying.');
    return asMap(jsonDecode(response.body));
  }
  /// Stream selected videos instead of buffering the entire file in Dart.
  /// The server caps uploads at 256 MiB and streams to YouTube privately.
  /// Transfer progress represents bytes sent from the device, NOT review
  /// or confirmation that YouTube accepted the upload.
  Future<Map<String,dynamic>> uploadSelected(
    String draftId,String channelId,PlatformFile file, {
    void Function(int percent)? onTransferProgress,
  }) async {
    if(file.size <= 0 || file.size > YouTubeUploadRules.directGatewayMaxBytes)
      throw const ApiFailure(
        'Direct WeuTube uploads currently support 256 MiB. YouTube allows '
        'up to 256 GB; larger files need a resumable WeuTube upload pathway.');
    if(!signedIn) throw const ApiFailure('Sign in first.',401);
    final rawStream = file.readStream ??
      (file.bytes == null ? null : Stream<List<int>>.value(file.bytes!));
    if(rawStream == null)
      throw const ApiFailure('Unable to read this video from your device.');
    final type = YouTubeUploadRules.mimeForFilename(file.name);
    if(type == null)
      throw const ApiFailure(
        'This file container is not in the supported YouTube video list.');
    var transferred = 0;
    var reported = -1;
    final countingStream = rawStream.map((chunk) {
      transferred += chunk.length;
      final percent = (transferred * 100 ~/ file.size).clamp(0,100);
      if(percent > reported) {
        reported = percent;
        onTransferProgress?.call(percent);
      }
      return chunk;
    });
    final request = http.MultipartRequest('POST',
      uri('/api/creator/videos/'+Uri.encodeComponent(draftId)+'/private-upload'))
      ..headers['Authorization']='Bearer '+accessToken!
      ..fields['channelId']=channelId
      ..files.add(http.MultipartFile(
        'file',countingStream,file.size,filename:file.name,
        contentType: MediaType.parse(type)));
    http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(minutes: 20)));
    } catch (_) {
      throw const ApiFailure('Connection lost or upload timed out.');
    }
    if(response.statusCode==401)
      throw const ApiFailure('Your session expired.',401);
    if(response.statusCode==403)
      throw const ApiFailure('Channel upload permission denied.',403);
    if(response.statusCode==413)
      throw const ApiFailure('File exceeds the server upload limit.',413);
    if(response.statusCode!=200 && response.statusCode!=201)
      throw ApiFailure('Upload returned HTTP ${response.statusCode}.',response.statusCode);
    return asMap(jsonDecode(response.body));
  }

  /// YouTube owns uploaded video bytes; this server only relays bounded chunks.
  /// No WeuTube-specific total file size cap is imposed.
  Future<Map<String,dynamic>> beginYouTubeUpload(
    String draftId,String channelId,PlatformFile file) async =>
    asMap(await call('POST','/api/creator/uploads',data:{
      'draftId':draftId,
      'channelId':channelId,
      'fileName':file.name,
      'totalBytes':file.size,
    }));

  Future<Map<String,dynamic>> youtubeUploadStatus(String sessionId) async =>
    asMap(await call('GET','/api/creator/uploads/'+Uri.encodeComponent(sessionId)));

  Future<void> cancelYouTubeUpload(String sessionId) async =>
    call('DELETE','/api/creator/uploads/'+Uri.encodeComponent(sessionId));

  Future<Map<String,dynamic>> sendYouTubeChunk(
    String sessionId,int first,int total,Uint8List bytes,
    {bool retryAuthentication=true}) async {
    if(!signedIn) throw const ApiFailure('Sign in first.',401);
    if(bytes.isEmpty || bytes.length>8*1024*1024)
      throw const ApiFailure('Invalid video transfer chunk');
    final last = first+bytes.length-1;
    final request=http.Request('PUT',uri(
      '/api/creator/uploads/'+Uri.encodeComponent(sessionId)+'/chunk'))
      ..headers.addAll({
        'Authorization':'Bearer '+accessToken!,
        'Accept':'application/json',
        'Content-Type':'application/octet-stream',
        'Content-Range':'bytes $first-$last/$total',
      })
      ..bodyBytes = bytes;
    http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(minutes: 4)));
    } catch (_) {
      throw const ApiFailure(
        'Connection interrupted. The app must check YouTube progress before retrying.');
    }
    if(response.statusCode==401 && retryAuthentication && refreshToken!=null) {
      await refresh();
      return sendYouTubeChunk(sessionId,first,total,bytes,
        retryAuthentication:false);
    }
    if(response.statusCode==401) throw const ApiFailure('Session expired.',401);
    if(response.statusCode==403) throw const ApiFailure('Channel permission denied.',403);
    if(response.statusCode==404)
      throw const ApiFailure('Upload session is unavailable.',404);
    if(response.statusCode==409)
      throw const ApiFailure('Upload progress changed. Check before resuming.',409);
    if(response.statusCode<200 || response.statusCode>=300)
      throw ApiFailure('YouTube transfer unavailable. HTTP ${response.statusCode}.',
        response.statusCode);
    return asMap(jsonDecode(response.body));
  }

  /// Progress is taken exclusively from Google's acknowledged byte offset,
  /// not from how quickly the device wrote data into a socket.
  Future<Map<String,dynamic>> transferToYouTube(
    String sessionId,PlatformFile file,{
    void Function(int acknowledgedBytes,int totalBytes)? onProgress,
    bool Function()? shouldPause,
  }) async {
    if(file.size <= 0 || file.size > YouTubeUploadRules.youtubeMaxBytes)
      throw const ApiFailure('This video is larger than YouTube accepts.');
    final source=file.readStream ??
      (file.bytes==null ? null : Stream<List<int>>.value(file.bytes!));
    if(source==null)
      throw const ApiFailure('Reselect the original video to resume uploading.');
    final reader=UploadChunkReader(source);
    try {
      var state=await youtubeUploadStatus(sessionId);
      final total=(state['totalBytes'] as num).toInt();
      if(total!=file.size)
        throw const ApiFailure('Reselect the same video file to resume.');
      var acknowledged=(state['acknowledgedBytes'] as num).toInt();
      onProgress?.call(acknowledged,total);
      await reader.skip(acknowledged);
      while(acknowledged<total) {
        if(shouldPause?.call()==true) return state;
        final length=(total-acknowledged < 8*1024*1024)
          ? total-acknowledged : 8*1024*1024;
        final chunk=await reader.readExact(length);
        try {
          state=await sendYouTubeChunk(sessionId,acknowledged,total,chunk);
        } on ApiFailure {
          // The server may have relayed some or all bytes before the timeout.
          // Status GET reconciles with Google, never a blind duplicate PUT.
          await youtubeUploadStatus(sessionId);
          rethrow;
        }
        final accepted=(state['acknowledgedBytes'] as num).toInt();
        if(accepted<acknowledged || accepted>total)
          throw const ApiFailure('YouTube returned an inconsistent upload offset.');
        if(accepted<acknowledged+length) {
          throw const ApiFailure(
            'YouTube accepted only part of the chunk. Reselect the original video '
            'and resume from the confirmed offset.');
        }
        acknowledged=accepted;
        onProgress?.call(acknowledged,total);
        if(state['status']=='COMPLETED') break;
      }
      return state;
    } finally {
      await reader.close();
    }
  }

  /// Public, clearly differentiated demo fixtures and real published submissions.
  Future<Map<String,dynamic>> publicFeed() async =>
    asMap(await call('GET','/api/public/social/feed?limit=30&includeDemo=true',auth:false));
  Future<Map<String,dynamic>> socialState() async =>
    asMap(await call('GET','/api/social/me'));
  Future<void> reactVideo(String id,String reaction,bool on) async {
    if(id.startsWith('demo-')) throw const ApiFailure('Demo reactions are local only.');
    if(reaction!='like'&&reaction!='save')throw const ApiFailure('Unsupported reaction.');
    await call(on?'PUT':'DELETE',
      '/api/social/videos/'+Uri.encodeComponent(id)+'/'+reaction);
  }
  Future<void> followCreator(String id,bool on) async =>
    call(on?'PUT':'DELETE','/api/social/creators/'+Uri.encodeComponent(id)+'/follow');
  Future<List<Map<String,dynamic>>> comments(String videoId) async {
    // Published comments are public; writing still requires Cognito login.
    final result=await call('GET',
      '/api/public/social/videos/'+Uri.encodeComponent(videoId)+'/comments',auth:false);
    return (result is List ? result : <dynamic>[])
      .whereType<Map<String,dynamic>>().toList();
  }
  Future<Map<String,dynamic>> postComment(String videoId,String message) async =>
    asMap(await call('POST','/api/social/videos/'+Uri.encodeComponent(videoId)+'/comments',
      data:{'text':message}));
  Future<List<Map<String,dynamic>>> reviewQueue() => list('/api/admin/reviews/queue');
  Future<Map<String,dynamic>> reviewDecision(String id,String decision,String reason) async =>
    asMap(await call('POST','/api/admin/reviews/'+Uri.encodeComponent(id)+'/decision',
      data:{'decision':decision,'reason':reason}));
  Future<List<Map<String,dynamic>>> adminChannels() => list('/api/admin/youtube/channels');
  Future<Map<String,dynamic>> channelAuthorization() async =>
    asMap(await call('POST','/api/admin/youtube/authorization'));
  Future<Map<String,dynamic>> grantChannelToMyAccount(String id) async =>
    asMap(await call('POST','/api/admin/channels/'+Uri.encodeComponent(id)+'/grant-me'));
  Future<Map<String,dynamic>> grantChannel(String id,String creatorSubject) async =>
    asMap(await call('POST','/api/admin/channels/'+Uri.encodeComponent(id)+'/creators',
      data:{'creatorSubject':creatorSubject}));
  Future<List<Map<String,dynamic>>> pendingPublication() => list('/api/admin/videos/approved');
  Future<Map<String,dynamic>> publishVideo(String id) async =>
    asMap(await call('POST','/api/admin/videos/'+Uri.encodeComponent(id)+'/publish'));
  Future<Map<String,dynamic>> reconcilePublish(String id) async =>
    asMap(await call('POST','/api/admin/videos/'+Uri.encodeComponent(id)+'/reconcile-publish'));
  Future<List<Map<String,dynamic>>> payoutQueue() => list('/api/admin/payouts/queue');
  Future<Map<String,dynamic>> payoutDecision(String id,String decision,String reason) async =>
    asMap(await call('POST','/api/admin/payouts/'+Uri.encodeComponent(id)+'/decision',
      data:{'decision':decision,'reason':reason}));
  void dispose() => _client.close();
}
