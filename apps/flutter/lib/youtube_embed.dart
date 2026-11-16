import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'product_ui.dart' show coral, navy;

/// Accept only genuine YouTube video links. Never pass untrusted page URLs
/// directly to a WebView or try to extract video stream URLs.
String? youtubeVideoIdFromUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty ||
      uri.hasPort) return null;
  final host = uri.host.toLowerCase();
  String? candidate;
  if (host == 'youtube.com' || host == 'www.youtube.com' ||
      host == 'm.youtube.com') {
    if (uri.path == '/watch') {
      candidate = uri.queryParameters['v'];
    } else if (uri.pathSegments.length == 2 &&
        const ['shorts', 'embed', 'live'].contains(uri.pathSegments.first)) {
      candidate = uri.pathSegments.last;
    }
  } else if (host == 'youtu.be' || host == 'www.youtu.be') {
    if (uri.pathSegments.length == 1) candidate = uri.pathSegments.first;
  }
  return candidate != null &&
      RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(candidate)
      ? candidate : null;
}

/// Only mounts a YouTube iframe for the currently visible item. Adjacent
/// PageView items remain thumbnails, not background players or preloads.
/// The iframe is NEVER covered by WeuTube captions, controls or engagement
/// overlays. YouTube's own branding, ads and controls remain intact.
class WeuTubeYoutubeStage extends StatefulWidget {
  const WeuTubeYoutubeStage({
    super.key,
    required this.videoId,
    required this.thumbnailUrl,
    required this.active,
  });

  final String videoId;
  final String thumbnailUrl;
  final bool active;

  @override
  State<WeuTubeYoutubeStage> createState() => _WeuTubeYoutubeStageState();
}

class _WeuTubeYoutubeStageState extends State<WeuTubeYoutubeStage>
    with WidgetsBindingObserver {
  YoutubePlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _configurePlayer();
  }

  @override
  void didUpdateWidget(covariant WeuTubeYoutubeStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active ||
        oldWidget.videoId != widget.videoId) {
      _configurePlayer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      // Never continue YouTube audio or playback behind other screens.
      _controller?.pause();
    }
    // Do not force a paused or unmuted video to restart on app resume.
  }

  void _configurePlayer() {
    final previous = _controller;
    _controller = null;
    previous?.pause();
    previous?.close();
    _error = null;
    if (!widget.active) return;

    final controller = YoutubePlayerController(
      params: YoutubePlayerParams(
        mute: true,
        playsInline: true,
        showControls: true,
        showFullscreenButton: true,
        privacyEnhancedMode: true,
        // Android/iOS WebViews must identify the *installed app*, not send
        // a null Referer which causes YouTube 153 playback failures.
        // Flutter CI generates applicationId com.weutube.weutube.
        // Web uses the actual page origin supplied by the iframe plugin.
        origin: kIsWeb ? null : 'https://com.weutube.weutube',
      ),
    );
    _controller = controller;
    // Mount the iframe before requesting playback, catching WebView or
    // autoplay rejections so a failed embed never crashes the feed.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !widget.active ||
          !identical(controller, _controller)) return;
      try {
        await controller.loadVideoById(videoId: widget.videoId);
      } catch (_) {
        if (mounted && identical(controller, _controller)) {
          setState(() => _error =
              'Embedded playback unavailable. Open on YouTube below.');
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.pause();
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!widget.active || controller == null) {
      return Stack(fit: StackFit.expand, children: [
        ColoredBox(color: navy, child: Image.network(
          widget.thumbnailUrl, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.play_circle_outline_rounded, color: Colors.white, size: 48),
        )),
        const Center(child: Icon(Icons.play_circle_outline_rounded,
          size: 56, color: Colors.white)),
      ]);
    }

    return Column(children: [
      // This is the unmodified YouTube embedded player. No overlays, custom
      // tap handlers, frames or decorative masks are placed on its surface.
      YoutubePlayer(
        controller: controller,
        aspectRatio: 16 / 9,
        enableFullScreenOnVerticalDrag: false,
        autoFullScreen: false,
        backgroundColor: navy,
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(_error!,
            style: const TextStyle(color: coral, fontSize: 11),
            textAlign: TextAlign.center),
        ),
    ]);
  }
}
