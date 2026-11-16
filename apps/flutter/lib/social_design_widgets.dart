import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'product_ui.dart' show navy, coral, slate;

/// User-approved brand palette: no system lavender selection backgrounds.
class WeuSocialBottomBar extends StatelessWidget {
  const WeuSocialBottomBar({super.key,required this.selected,required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;
  static const tabs=['Home','Explore','Shorts','Create','You'];
  static const icons=[
    Icons.home_rounded,Icons.explore_rounded,Icons.play_circle_fill_rounded,
    Icons.add_box_rounded,Icons.person_rounded
  ];
  static const outline=[
    Icons.home_outlined,Icons.explore_outlined,Icons.play_circle_outline_rounded,
    Icons.add_box_outlined,Icons.person_outline_rounded
  ];
  @override
  Widget build(BuildContext context)=>Container(
    decoration:const BoxDecoration(color:Colors.white,
      border:Border(top:BorderSide(color:Color(0xFFECEDF2),width:1))),
    padding:const EdgeInsets.fromLTRB(8,5,8,5),
    child:SafeArea(top:false,child:Row(children:[
      for(var i=0;i<tabs.length;i++)
        Expanded(child:Semantics(button:true,label:tabs[i],
          selected:selected==tabs[i],child:InkWell(
            borderRadius:BorderRadius.circular(14),
            onTap:()=>onSelect(tabs[i]),
            child:Column(mainAxisSize:MainAxisSize.min,children:[
              AnimatedContainer(duration:const Duration(milliseconds:210),
                padding:const EdgeInsets.symmetric(horizontal:14,vertical:5),
                decoration:BoxDecoration(
                  color:selected==tabs[i]?coral.withValues(alpha:.10):Colors.transparent,
                  borderRadius:BorderRadius.circular(12)),
                child:Icon(selected==tabs[i]?icons[i]:outline[i],
                  size:24,color:selected==tabs[i]?coral:slate)),
              const SizedBox(height:3),
              Text(tabs[i],style:TextStyle(
                color:selected==tabs[i]?coral:slate,fontSize:10,
                fontWeight:selected==tabs[i]?FontWeight.w900:FontWeight.w600)),
            ]))))
    ])));
}

class CreatorPortrait extends StatelessWidget {
  final String name,imageUrl;
  final double radius;
  final bool highlighted;
  const CreatorPortrait({super.key,required this.name,required this.imageUrl,
    this.radius=20,this.highlighted=false});
  @override
  Widget build(BuildContext context) {
    final initial=name.trim().isEmpty?'C':name.trim()[0].toUpperCase();
    return Container(
      width:radius*2+4,height:radius*2+4,padding:const EdgeInsets.all(2),
      decoration:BoxDecoration(shape:BoxShape.circle,
        border:highlighted?Border.all(color:coral,width:1.8):null),
      child:ClipOval(child:imageUrl.startsWith('https://')?
        Image.network(imageUrl,fit:BoxFit.cover,
          errorBuilder:(_,__,___)=>_fallback(initial)):
        _fallback(initial)));
  }
  Widget _fallback(String initial)=>Container(
    color:navy,alignment:Alignment.center,
    child:Text(initial,style:TextStyle(color:Colors.white,
      fontSize:radius*.85,fontWeight:FontWeight.w800)));
}

/// Auto-plays *muted* only for the active visible preview. This prevents a
/// scrolling feed from opening dozens of decoders/network streams.
/// Genuine YouTube published videos still open their approved public link.
class SocialMediaStage extends StatefulWidget {
  final String thumbnailUrl;
  final String? previewUrl;
  final bool active;
  final bool immersive;
  final VoidCallback onTap,onDoubleTap;
  const SocialMediaStage({super.key,required this.thumbnailUrl,
    this.previewUrl,required this.active,required this.onTap,
    required this.onDoubleTap,this.immersive=false});
  @override
  State<SocialMediaStage> createState()=>_SocialMediaStageState();
}
class _SocialMediaStageState extends State<SocialMediaStage>
    with WidgetsBindingObserver {
  VideoPlayerController? player;
  bool ready = false, failed = false, muted = true, manuallyPaused = false;
  int epoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _switch();
  }

  @override
  void didUpdateWidget(covariant SocialMediaStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active ||
        oldWidget.previewUrl != widget.previewUrl) {
      _switch();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = player;
    if (controller == null || !ready) return;
    if (state != AppLifecycleState.resumed) {
      controller.pause();
    } else if (widget.active && !manuallyPaused) {
      controller.setVolume(muted ? 0 : 1);
      controller.play();
    }
  }

  void _switch() {
    final ticket = ++epoch;
    final old = player;
    player = null;
    ready = false;
    failed = false;
    muted = true;
    manuallyPaused = false;
    if (old != null) {
      old.pause();
      old.dispose();
    }
    final raw = widget.previewUrl;
    final uri = raw == null ? null : Uri.tryParse(raw);
    // Only the trusted sample-video CDN is eligible for inline playback.
    // Published videos still use their validated public YouTube link.
    if (!widget.active || uri == null || uri.scheme != 'https' ||
        uri.host != 'storage.googleapis.com') return;

    final controller = VideoPlayerController.networkUrl(uri);
    player = controller;
    () async {
      try {
        await controller.initialize();
        if (!mounted || ticket != epoch) {
          await controller.dispose();
          return;
        }
        await controller.setVolume(0);
        await controller.setLooping(true);
        await controller.play();
        if (mounted && ticket == epoch) setState(() => ready = true);
      } catch (_) {
        if (mounted && ticket == epoch) setState(() => failed = true);
      }
    }();
  }

  // First tap enables audio; later taps pause/resume. The audio control
  // remains available to re-mute without interrupting playback.
  Future<void> _handleTap() async {
    final controller = player;
    if (!ready || controller == null) {
      widget.onTap();
      return;
    }
    try {
      if (muted) {
        await controller.setVolume(1);
        if (mounted && identical(controller, player)) {
          setState(() => muted = false);
        }
      } else if (controller.value.isPlaying) {
        await controller.pause();
        if (mounted && identical(controller, player)) {
          setState(() => manuallyPaused = true);
        }
      } else {
        await controller.play();
        if (mounted && identical(controller, player)) {
          setState(() => manuallyPaused = false);
        }
      }
    } catch (_) {
      widget.onTap();
    }
  }

  Future<void> _toggleMute() async {
    final controller = player;
    if (!ready || controller == null) return;
    final next = !muted;
    try {
      await controller.setVolume(next ? 0 : 1);
      if (mounted && identical(controller, player)) {
        setState(() => muted = next);
      }
    } catch (_) {
      // The current preview may have been disposed while the tap completed.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    epoch++;
    player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = player;
    final playing = ready && controller != null && !manuallyPaused;
    return GestureDetector(
      onTap: _handleTap,
      onDoubleTap: widget.onDoubleTap,
      child: Stack(fit: StackFit.expand, children: [
        Container(
          color: const Color(0xFF15254A),
          child: Image.network(widget.thumbnailUrl, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.landscape_rounded,
                color: Colors.white54, size: 70)))),
        if (ready && controller != null && controller.value.isInitialized)
          LayoutBuilder(builder: (context, constraints) {
            final size = controller.value.size;
            if (size.width == 0 || size.height == 0) {
              return const SizedBox.shrink();
            }
            return ClipRect(child: FittedBox(fit: BoxFit.cover,
              child: SizedBox(width: size.width, height: size.height,
                child: VideoPlayer(controller))));
          }),
        if (widget.immersive)
          const DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              stops: [0, .28, .52, 1],
              colors: [Color(0x55000000), Colors.transparent,
                Color(0x30000000), Color(0xD9000000)]))),
        if (!playing)
          Center(child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .93),
              shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow_rounded,
              color: coral, size: 32))),
        if (ready && controller != null)
          Positioned(top: 12, right: 12,
            child: Semantics(
              button: true,
              label: muted ? 'Unmute video' : 'Mute video',
              child: Material(color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleMute,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(muted ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                        color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(muted ? 'Tap to unmute' : 'Sound on',
                        style: const TextStyle(color: Colors.white,
                          fontSize: 10, fontWeight: FontWeight.w700))
                    ]))))),
        if (ready && controller != null)
          Positioned(bottom: 0, left: 0, right: 0,
            child: VideoProgressIndicator(controller,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: coral,
                bufferedColor: Colors.white38,
                backgroundColor: Colors.white24)))
      ]));
  }
}
