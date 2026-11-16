import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_client.dart';
import 'youtube_upload_rules.dart';
import 'product_ui.dart' show navy, coral, slate;

enum UploadAccess { signedOut, checking, ready, noChannel, denied, failed }

/// The one and only mobile Create workflow. Admin-granted YouTube channel
/// rights are checked BEFORE displaying the uploading form. No fake "connect"
/// button can bypass server-side grant and OAuth ownership restrictions.
class WeuTubeUploadComposer extends StatefulWidget {
  const WeuTubeUploadComposer({
    super.key,
    required this.api,
    required this.onSignIn,
    required this.onViewVideos,
  });

  final WeuTubeApi api;
  final VoidCallback onSignIn;
  final VoidCallback onViewVideos;

  @override
  State<WeuTubeUploadComposer> createState() => _WeuTubeUploadComposerState();
}

class _WeuTubeUploadComposerState extends State<WeuTubeUploadComposer> {
  static const maxBytes = YouTubeUploadRules.youtubeMaxBytes;
  static const categories = [
    'Travel', 'Art', 'Lifestyle', 'Storytelling', 'Education',
    'Entertainment', 'Technology', 'Stories',
  ];
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();

  UploadAccess _access = UploadAccess.signedOut;
  List<Map<String,dynamic>> _channels = [];
  String? _channel;
  PlatformFile? _file;
  String _category = 'Lifestyle';
  String? _error;
  bool _sending = false;
  bool _pauseRequested = false;
  String? _draftId;
  String? _sessionId;
  String? _resumeName;
  int? _resumeSize;
  int _transferPercent = 0;

  static const _prefSession = 'weutube.resumable.session';
  static const _prefDraft = 'weutube.resumable.draft';
  static const _prefName = 'weutube.resumable.name';
  static const _prefSize = 'weutube.resumable.size';

  Future<void> _rememberPending(String sessionId,String draftId,
      PlatformFile file) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSession,sessionId);
    await prefs.setString(_prefDraft,draftId);
    await prefs.setString(_prefName,file.name);
    await prefs.setInt(_prefSize,file.size);
  }
  Future<void> _restorePending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id=prefs.getString(_prefSession);
      if(id==null || !mounted) return;
      setState(() {
        _sessionId=id;
        _draftId=prefs.getString(_prefDraft);
        _resumeName=prefs.getString(_prefName);
        _resumeSize=prefs.getInt(_prefSize);
      });
    } catch (_) {
      // Local persistence is best-effort; server-side ownership stays strict.
    }
  }
  Future<void> _forgetPending() async {
    final prefs=await SharedPreferences.getInstance();
    for(final key in [_prefSession,_prefDraft,_prefName,_prefSize]) {
      await prefs.remove(key);
    }
    if(mounted) setState(() {
      _sessionId=null;
      _draftId=null;
      _resumeName=null;
      _resumeSize=null;
      _file=null;
      _transferPercent=0;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.api.signedIn) {
      _access = UploadAccess.checking;
      _loadChannels();
    }
  }

  @override
  void didUpdateWidget(covariant WeuTubeUploadComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api.signedIn != widget.api.signedIn) {
      if (widget.api.signedIn) {
        _access = UploadAccess.checking;
        _loadChannels();
      } else {
        _access = UploadAccess.signedOut;
        _channels = [];
        _channel = null;
        _file = null;
        _draftId = null;
        _sessionId = null;
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadChannels() async {
    if (!widget.api.signedIn) {
      if (mounted) setState(() => _access = UploadAccess.signedOut);
      return;
    }
    setState(() {
      _access = UploadAccess.checking;
      _error = null;
      _channels = [];
      _channel = null;
    });
    var identityVerified = false;
    try {
      // First validate Cognito independently of the channel grant lookup.
      // No grant should be an authenticated empty state, never a 403.
      final session = await widget.api.creatorSession();
      identityVerified = true;
      if(!mounted) return;
      final access = session['uploadAccess']?.toString();
      if(access == 'NO_CHANNEL_GRANT' || access == 'CHANNEL_NOT_CONNECTED') {
        setState(() {
          _access = UploadAccess.noChannel;
          _error = access == 'NO_CHANNEL_GRANT'
            ? 'Your account is signed in, but no YouTube channel is granted yet.'
            : 'Your channel grant exists, but its YouTube connection is unavailable. '
              'A channel administrator must reconnect it.';
        });
        return;
      }
      final granted = await widget.api.grantedChannels();
      if (!mounted) return;
      final channels = granted.where((c) =>
          (c['channelId']?.toString() ?? '').isNotEmpty).toList();
      setState(() {
        _channels = channels;
        _channel = channels.isEmpty ? null : channels.first['channelId'].toString();
        _access = channels.isEmpty ? UploadAccess.noChannel : UploadAccess.ready;
      });
      if(channels.isNotEmpty) await _restorePending();
    } on ApiFailure catch (ex) {
      if (!mounted) return;
      setState(() {
        _access = ex.code == 401 || ex.code == 403
          ? UploadAccess.denied : UploadAccess.failed;
        _error = ex.code == 403 && identityVerified
          ? 'Your sign-in is valid, but the channel authorization request '
            'was denied (HTTP 403). Check backend channel endpoint permissions.'
          : ex.code == 401 || ex.code == 403
            ? 'Your current sign-in was rejected by the API (HTTP ${ex.code}). '
              'Sign in again. If it continues, backend Cognito token '
              'validation needs investigation.'
            : ex.message;
      });
    } catch (_) {
      if (mounted) setState(() {
        _access = UploadAccess.failed;
        _error = 'Unable to check YouTube channel access. Try again.';
      });
    }
  }

  Future<void> _chooseVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        // OS 'video' pickers often hide YouTube-supported AVI/WMV/MPEG.
        // We validate the selected extension before enabling submission.
        type: FileType.any,
        withData: false,
        withReadStream: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final file = result.files.first;
      if (YouTubeUploadRules.mimeForFilename(file.name) == null) {
        setState(() {
          _file = null;
          _error = 'Unsupported container. Choose MP4, MOV, MPEG, AVI, '
            'WMV, FLV, 3GPP or WebM. ProRes/HEVC codecs need a '
            'supported video container.';
        });
        return;
      }
      if (file.size <= 0 || file.size > maxBytes) {
        setState(() {
          _file = null;
          _error = 'The selected video exceeds YouTube’s limit of 256 GB '
            'or has no data.';
        });
        return;
      }
      if (_sessionId != null &&
          (file.name != _resumeName || file.size != _resumeSize)) {
        setState(() {
          _file = null;
          _error = 'Select the same original video to resume your current upload, '
            'or cancel that upload to start a different one.';
        });
        return;
      }
      if (file.readStream == null && file.bytes == null) {
        setState(() => _error = 'Your device could not read that video. '
          'Choose another file.');
        return;
      }
      setState(() {
        _file = file;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error =
        'Unable to select a video on this device. Please try again.');
    }
  }

  Future<void> _submit() async {
    if (_sending || _access != UploadAccess.ready) return;
    final video=_file;
    if(video==null) {
      setState(() => _error = _sessionId==null
        ? 'Choose a video before uploading.'
        : 'Reselect the same original video to resume uploading.');
      return;
    }
    if (_sessionId == null && !(_form.currentState?.validate() ?? false)) return;
    final channel=_channel;
    if(channel==null) {
      setState(() => _error = 'Select an authorized channel.');
      return;
    }
    setState(() {
      _sending=true;
      _pauseRequested=false;
      _error=null;
    });
    try {
      var id=_sessionId;
      if(id==null) {
        // Create metadata exactly once; a repeated upload session for a draft
        // is idempotent in the API and cannot create a duplicate video.
        final draftId=_draftId ??
          (await widget.api.createDraft(_title.text.trim()))['id']?.toString();
        if(draftId==null || draftId.isEmpty)
          throw const ApiFailure('Unable to create a video draft.');
        _draftId=draftId;
        await widget.api.updateDraftMetadata(draftId,_title.text.trim(),
          _description.text.trim(),_category);
        final session=await widget.api.beginYouTubeUpload(draftId,channel,video);
        id=session['id']?.toString();
        if(id==null || id.isEmpty)
          throw const ApiFailure('YouTube upload session was not created.');
        _sessionId=id;
        _resumeName=video.name;
        _resumeSize=video.size;
        await _rememberPending(id,draftId,video);
      }
      final result=await widget.api.transferToYouTube(id,video,
        shouldPause:()=>_pauseRequested,
        onProgress:(ack,total) {
          if(!mounted) return;
          setState(() => _transferPercent=(ack*100 ~/ total).clamp(0,100));
        });
      if(!mounted) return;
      if(result['status']=='COMPLETED') {
        await _forgetPending();
        if(!mounted) return;
        widget.onViewVideos();
      } else {
        setState(() {
          _file=null;
          _error='Upload paused. Reselect the same original video and tap '
            'Resume to continue from YouTube’s confirmed progress.';
        });
      }
    } on ApiFailure catch(ex) {
      if(!mounted) return;
      setState(() {
        _file=null; // FilePicker streams are single-use: reselect to resume.
        _error=_sessionId==null
          ? ex.message
          : 'Upload interrupted. Your confirmed YouTube progress is saved. '
            'Reselect the original video and tap Resume. (${ex.message})';
      });
    } catch(_) {
      if(!mounted) return;
      setState(() {
        _file=null;
        _error=_sessionId==null
          ? 'Could not start the upload. Try again.'
          : 'Upload paused. Reselect the original video to resume.';
      });
    } finally {
      if(mounted) setState(() => _sending=false);
    }
  }

  Future<void> _cancelPending() async {
    final session=_sessionId;
    if(_sending || session==null) return;
    setState(() => _sending=true);
    try {
      await widget.api.cancelYouTubeUpload(session);
      await _forgetPending();
    } on ApiFailure catch(ex) {
      if(mounted) setState(() => _error=ex.message);
    } finally {
      if(mounted) setState(() => _sending=false);
    }
  }

  Widget _primary(String label, VoidCallback? action, {IconData? icon}) =>
    SizedBox(width: double.infinity, height: 52,
      child: FilledButton.icon(
        onPressed: action,
        style: FilledButton.styleFrom(
          backgroundColor: coral,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13))),
        icon: Icon(icon ?? Icons.arrow_forward_rounded, size: 20),
        label: Text(label, style: const TextStyle(
          fontWeight: FontWeight.w800, fontSize: 14))));

  Widget _info(String text, {bool warning = false}) =>
    Container(width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: warning ? const Color(0xFFFFF0ED) : const Color(0xFFF3F5FA),
        borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start,children: [
        Icon(warning ? Icons.info_outline_rounded : Icons.lock_outline_rounded,
          color: warning ? coral : navy,size: 19),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(
          color: navy,fontSize: 13,height: 1.45))),
      ]));

  void _reauthenticate() {
    // Re-authentication does not bypass server channel grants.
    widget.api.clear();
    widget.onSignIn();
  }

  Widget _blocked(String heading, String details, {
    bool canRetry = false,
    bool canSignIn = false,
    bool canReauthenticate = false,
  }) => Column(crossAxisAlignment: CrossAxisAlignment.start,children: [
    const SizedBox(height: 12),
    Icon(canSignIn ? Icons.lock_outline_rounded
      : Icons.video_call_outlined,color: navy,size: 34),
    const SizedBox(height: 16),
    Text(heading,style: const TextStyle(
      fontSize: 20,color: navy,fontWeight: FontWeight.w900)),
    const SizedBox(height: 8),
    Text(details,style: const TextStyle(
      fontSize: 14,color: slate,height: 1.5)),
    if(_error != null) ...[
      const SizedBox(height: 14),
      _info(_error!,warning: true),
    ],
    const SizedBox(height: 22),
    if(canSignIn) _primary('Sign in to upload',widget.onSignIn,
      icon: Icons.login_rounded),
    if(canRetry) _primary('Check channel access again',_loadChannels,
      icon: Icons.refresh_rounded),
    if(canReauthenticate) _primary('Sign in again',_reauthenticate,
      icon: Icons.login_rounded),
    if(widget.api.signedIn) ...[
      const SizedBox(height: 10),
      SizedBox(width: double.infinity,
        child: TextButton.icon(onPressed: widget.onViewVideos,
          icon: const Icon(Icons.video_library_outlined,size: 18),
          label: const Text('View My Videos'))),
    ],
  ]);

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(text,style: const TextStyle(color: navy,
      fontSize: 13,fontWeight: FontWeight.w800)));

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: slate,fontSize: 13),
    filled: true,
    fillColor: const Color(0xFFF9FAFD),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 13,vertical: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFDFE4ED))),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: navy,width: 1.5)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  Widget _readyForm() {
    return Form(key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,children: [
        const SizedBox(height: 10),
        _fieldLabel('Video'),
        InkWell(onTap: _sending ? null : _chooseVideo,
          borderRadius: BorderRadius.circular(14),
          child: Container(width: double.infinity,
            constraints: const BoxConstraints(minHeight: 104),
            padding: const EdgeInsets.symmetric(horizontal: 16,vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFE),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD5DCE8))),
            child: Row(children: [
              const Icon(Icons.video_file_outlined,color: coral,size: 30),
              const SizedBox(width: 13),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,children: [
                  Text(_file?.name ?? 'Choose a video',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: navy,
                      fontSize: 15,fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(_file == null
                    ? (_sessionId==null ? 'YouTube formats · up to 256 GB / 12 hours'
                    : 'Reselect ${_resumeName ?? "your original video"} to resume')
                    : '${(_file!.size / (1024 * 1024)).toStringAsFixed(1)} MB · Tap to change',
                    style: const TextStyle(color: slate,fontSize: 12)),
                ])),
              const Icon(Icons.add_circle_outline_rounded,color: navy),
            ]))),
        const SizedBox(height: 18),
        _fieldLabel('Title'),
        TextFormField(
          key: const ValueKey('upload-video-title'),
          controller: _title,
          enabled: !_sending && _sessionId==null,
          maxLength: YouTubeUploadRules.titleMaxChars,
          maxLines: 1,
          textInputAction: TextInputAction.next,
          decoration: _decoration('Give your video a title'),
          validator: (v) => YouTubeUploadRules.titleError(v ?? '')),
        const SizedBox(height: 10),
        _fieldLabel('Description (optional)'),
        TextFormField(
          controller: _description,
          enabled: !_sending && _sessionId==null,
          minLines: 2,maxLines: 3,
          maxLength: YouTubeUploadRules.descriptionMaxUtf8Bytes,
          decoration: _decoration('Tell viewers what this video is about'),
          validator: (v) => YouTubeUploadRules.descriptionError(v ?? '')),
        const SizedBox(height: 10),
        _fieldLabel('Category'),
        DropdownButtonFormField<String>(
          key: const ValueKey('upload-video-category'),
          initialValue: _category,
          isExpanded: true,
          decoration: _decoration('Choose category'),
          items: categories.map((c) => DropdownMenuItem(
            value: c,child: Text(c))).toList(),
          onChanged: _sending || _sessionId!=null ? null :
            (value) => setState(() => _category = value ?? 'Lifestyle')),
        const SizedBox(height: 17),
        _fieldLabel('Authorized YouTube channel'),
        DropdownButtonFormField<String>(
          key: const ValueKey('upload-video-channel'),
          initialValue: _channel,
          isExpanded: true,
          decoration: _decoration('Choose an authorized channel'),
          items: _channels.map((c) => DropdownMenuItem<String>(
            value: c['channelId'].toString(),
            child: Text(c['displayName']?.toString() ??
              c['channelId'].toString(),
              overflow: TextOverflow.ellipsis))).toList(),
          onChanged: _sending || _sessionId!=null ? null :
            (value) => setState(() => _channel = value)),
        const SizedBox(height: 16),
        _info('YouTube accepts videos up to 256 GB or 12 hours on eligible '
          'channels. WeuTube relays small chunks directly to YouTube without '
          'storing a full video copy. Private review is required before publishing.'),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _info(_error!, warning: true),
        ],
        if (_sending) ...[
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: _transferPercent > 0 && _transferPercent < 100
              ? _transferPercent / 100 : null,
            color: coral,
            backgroundColor: const Color(0xFFECEFF6)),
          const SizedBox(height: 6),
          Text(_transferPercent == 100
            ? 'YouTube confirmed video upload. Finishing review handoff…'
            : 'YouTube accepted $_transferPercent% of this video',
            style: const TextStyle(color: slate,fontSize: 12)),
        ],
        const SizedBox(height: 19),
        _primary(_sending ? 'Uploading to YouTube…'
          : _sessionId!=null ? 'Resume YouTube upload'
          : 'Upload privately for review',
          _sending ? null : _submit,
          icon: Icons.cloud_upload_outlined),
        if(_sending) ...[
          const SizedBox(height: 8),
          SizedBox(width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(() => _pauseRequested=true),
              child: Text(_pauseRequested ? 'Pausing after current chunk…'
                : 'Pause upload'))),
        ],
        if(_sessionId!=null && !_sending) ...[
          const SizedBox(height: 8),
          SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _cancelPending,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancel pending upload'))),
        ],
        const SizedBox(height: 11),
        Text('Upload only videos you own or may distribute. YouTube retains '
          'the video; interrupted transfers can resume by reselecting the '
          'original file. Connection and YouTube channel eligibility apply.',
          style: const TextStyle(color: slate,fontSize: 11,height: 1.4)),
        const SizedBox(height: 28),
      ]));
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: Colors.white,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        children: [
          const Text('Create video', style: TextStyle(color: navy,
            fontSize: 26,fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const Text('Upload directly from your device.',
            style: TextStyle(color: slate,fontSize: 13)),
          const SizedBox(height: 10),
          if (_access == UploadAccess.signedOut)
            _blocked('Sign in to get started',
              'A WeuTube account and channel permission are required '
              'before you can upload.',canSignIn: true)
          else if (_access == UploadAccess.checking)
            const Padding(padding: EdgeInsets.symmetric(vertical: 48),
              child: Column(children: [
                CircularProgressIndicator(color: coral),
                SizedBox(height: 15),
                Text('Checking your channel access…',
                  style: TextStyle(color: slate))]))
          else if (_access == UploadAccess.noChannel)
            _blocked('Channel access required',
              'You are signed in, but no YouTube channel has been granted '
              'to your account. A WeuTube administrator must connect a '
              'channel and grant you permission before uploading.',
              canRetry: true)
          else if (_access == UploadAccess.denied)
            _blocked('Sign-in verification failed',
              'The API rejected your current session before it could check '
              'which YouTube channels are available. Signing in again '
              'does not change channel permissions.',
              canReauthenticate: true,canRetry: true)
          else if (_access == UploadAccess.failed)
            _blocked('Unable to check channel access',
              'We could not verify whether you can upload. '
              'No file has been sent.',canRetry: true)
          else _readyForm(),
        ]));
  }
}
