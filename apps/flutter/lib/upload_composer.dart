import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
  static const maxBytes = YouTubeUploadRules.directGatewayMaxBytes;
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
  bool _uploadAttempted = false;
  String? _draftId;
  int _transferPercent = 0;

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
    try {
      final granted = await widget.api.grantedChannels();
      if (!mounted) return;
      final channels = granted.where((c) =>
          (c['channelId']?.toString() ?? '').isNotEmpty).toList();
      setState(() {
        _channels = channels;
        _channel = channels.isEmpty ? null : channels.first['channelId'].toString();
        _access = channels.isEmpty ? UploadAccess.noChannel : UploadAccess.ready;
      });
    } on ApiFailure catch (ex) {
      if (!mounted) return;
      setState(() {
        _access = ex.code == 401 ? UploadAccess.signedOut :
          ex.code == 403 ? UploadAccess.denied : UploadAccess.failed;
        _error = ex.code == 403
          ? 'Your account cannot access the channel authorization service. '
            'Check your account permissions with a WeuTube administrator.'
          : ex.code == 401 ? 'Your sign-in has expired. Sign in again.'
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
          _error = 'The current WeuTube direct uploader supports up to '
            '256 MiB per file. YouTube supports up to 256 GB or 12 hours; '
            'larger uploads need the new resumable upload infrastructure.';
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
    if (_sending || _uploadAttempted || _access != UploadAccess.ready) return;
    if (!(_form.currentState?.validate() ?? false)) return;
    final video = _file;
    if (video == null) {
      setState(() => _error = 'Choose a video before uploading.');
      return;
    }
    final channel = _channel;
    if (channel == null) {
      setState(() => _error = 'Select an authorized channel.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
      _transferPercent = 0;
    });
    try {
      // Avoid duplicate drafts if only the metadata stage failed.
      final draftId = _draftId ?? (await widget.api.createDraft(_title.text.trim()))['id']?.toString();
      if (draftId == null || draftId.isEmpty) {
        throw const ApiFailure('Could not create a draft. Try again.');
      }
      _draftId = draftId;
      await widget.api.updateDraftMetadata(
        draftId, _title.text.trim(), _description.text.trim(), _category);
      // From here, a timeout can mean the upload started remotely. Never
      // silently retry or create a second draft in that uncertain state.
      _uploadAttempted = true;
      await widget.api.uploadSelected(draftId, channel, video,
        onTransferProgress: (percent) {
          if (!mounted || percent <= _transferPercent) return;
          setState(() => _transferPercent = percent);
        });
      if (!mounted) return;
      setState(() => _sending = false);
      widget.onViewVideos();
    } on ApiFailure catch (ex) {
      if (!mounted) return;
      setState(() {
        _error = _uploadAttempted
          ? 'Upload outcome is uncertain. Check My Videos before trying again. '
            'A duplicate upload may be created otherwise. (${ex.message})'
          : ex.message;
        _sending = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _error = _uploadAttempted
          ? 'Upload outcome is uncertain. Check My Videos before retrying.'
          : 'Could not prepare the upload. Try again.';
        _sending = false;
      });
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

  Widget _blocked(String heading, String details, {
    bool canRetry = false,
    bool canSignIn = false,
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
        InkWell(onTap: _sending || _uploadAttempted ? null : _chooseVideo,
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
                    ? 'YouTube formats · current direct upload: 256 MiB'
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
          maxLength: YouTubeUploadRules.titleMaxChars,
          maxLines: 1,
          textInputAction: TextInputAction.next,
          decoration: _decoration('Give your video a title'),
          validator: (v) => YouTubeUploadRules.titleError(v ?? '')),
        const SizedBox(height: 10),
        _fieldLabel('Description (optional)'),
        TextFormField(
          controller: _description,
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
          onChanged: _sending || _uploadAttempted ? null :
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
          onChanged: _sending || _uploadAttempted ? null :
            (value) => setState(() => _channel = value)),
        const SizedBox(height: 16),
        _info('Your video is uploaded privately to the authorized YouTube '
          'channel, then reviewed by WeuTube before publishing. '
          'YouTube supports videos up to 12 hours/256 GB on eligible channels; '
          'the current WeuTube direct gateway is limited to 256 MiB.'),
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
            ? 'Video sent. Waiting for private YouTube upload confirmation…'
            : 'Sending video · $_transferPercent% of file transferred',
            style: const TextStyle(color: slate,fontSize: 12)),
        ],
        const SizedBox(height: 19),
        _primary(_sending ? 'Uploading privately…'
          : _uploadAttempted ? 'Check upload status in My Videos'
          : 'Upload privately for review',
          _sending ? null : _uploadAttempted ? widget.onViewVideos : _submit,
          icon: Icons.cloud_upload_outlined),
        const SizedBox(height: 11),
        Text('Upload only videos you own or have permission to distribute. '
          'Large uploads need a reliable connection; interrupted uploads are '
          'not yet resumable.',
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
            _blocked('Channel permissions unavailable',
              'Your account cannot use the upload service right now. '
              'An administrator may need to update your permissions.',
              canRetry: true)
          else if (_access == UploadAccess.failed)
            _blocked('Unable to check channel access',
              'We could not verify whether you can upload. '
              'No file has been sent.',canRetry: true)
          else _readyForm(),
        ]));
  }
}
