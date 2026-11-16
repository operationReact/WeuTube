import 'dart:convert';
import 'dart:typed_data';
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
      if(status==401) throw const ApiFailure('Invalid credentials or session.',401);
      if(status==403) throw const ApiFailure('Access denied.',403);
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
  Future<Map<String,dynamic>> dashboard() async => asMap(await call('GET','/api/creator/dashboard'));
  Future<List<Map<String,dynamic>>> videos() => list('/api/creator/videos');
  Future<Map<String,dynamic>> video(String id) async =>
    asMap(await call('GET','/api/creator/videos/'+Uri.encodeComponent(id)));
  Future<Map<String,dynamic>> createDraft(String title) async =>
    asMap(await call('POST','/api/creator/videos/drafts',data:{'title':title}));
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
  Future<List<Map<String,dynamic>>> comments(String videoId) =>
    list('/api/social/videos/'+Uri.encodeComponent(videoId)+'/comments');
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
