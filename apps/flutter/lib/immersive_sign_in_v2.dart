import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'product_ui.dart' show WeuTubeBrand, navy, coral, slate;

/// A compact cinematic scene around the exact approved WeuTube SVG.
/// All perspective, lighting and motion live on separate decorative layers;
/// the master logo file, its colors and its geometry are never transformed.
class ImmersiveBrandHero extends StatefulWidget {
  const ImmersiveBrandHero({super.key, this.compact = false});
  final bool compact;

  @override
  State<ImmersiveBrandHero> createState() => _ImmersiveBrandHeroState();
}

class _ImmersiveBrandHeroState extends State<ImmersiveBrandHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  double _parallax = 0;

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion) {
      _intro.value = 1;
    } else if (_intro.value == 0 && !_intro.isAnimating) {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  void _replay() {
    if (!_reduceMotion) _intro.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.compact ? 202.0 : 254.0;
    return Semantics(
      label: 'WeuTube welcome animation. Double tap to replay.',
      button: true,
      child: RepaintBoundary(
        child: GestureDetector(
          key: const ValueKey('immersive-brand-hero'),
          behavior: HitTestBehavior.opaque,
          onTap: _replay,
          onHorizontalDragUpdate: _reduceMotion ? null : (details) {
            setState(() {
              _parallax = (_parallax + details.delta.dx / 240.0)
                  .clamp(-0.18, 0.18);
            });
          },
          onHorizontalDragEnd: _reduceMotion ? null : (_) {
            setState(() => _parallax = 0);
          },
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _intro,
              builder: (context, _) {
                final t = _reduceMotion
                    ? 1.0
                    : Curves.easeOutCubic.transform(_intro.value);
                return LayoutBuilder(builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final logoWidth = math.min(w * .77, 354.0);
                  final logoLeft = (w - logoWidth) / 2;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(widget.compact ? 24 : 30),
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        const Positioned.fill(
                          child: ColoredBox(color: Color(0xFF10244A)),
                        ),
                        Positioned.fill(child: CustomPaint(
                          painter: _SceneLines(progress: t),
                        )),
                        // Perspective content cards enter *behind* the logo.
                        _storyCard(
                          left: -19 + 22 * t + _parallax * 26,
                          top: height * .15 - 19 * (1 - t),
                          rotation: -.14 + (1 - t) * -.23,
                          title: 'STORIES',
                          icon: Icons.video_library_outlined,
                          accent: const Color(0xFFDCE5F7),
                          progress: t,
                        ),
                        _storyCard(
                          left: w - 110 - 5 * t - _parallax * 30,
                          top: height * .12 + 19 * (1 - t),
                          rotation: .18 + (1 - t) * .21,
                          title: 'CREATORS',
                          icon: Icons.people_outline_rounded,
                          accent: const Color(0xFFFF6854),
                          progress: t,
                        ),
                        Positioned(
                          left: logoLeft,
                          top: height * .365 + 13 * (1 - t),
                          width: logoWidth,
                          child: Opacity(
                            opacity: ((t - .12) / .45).clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(_parallax * 4, 0),
                              // Only the surrounding surface moves; SVG
                              // remains upright, flat and undistorted.
                              child: Container(
                                height: widget.compact ? 70 : 86,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 15),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFEFD),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFF0F2F6)),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x3D000A29),
                                      blurRadius: 22, offset: Offset(0, 13)),
                                    BoxShadow(color: Color(0x2201092C),
                                      blurRadius: 0, offset: Offset(0, 5)),
                                  ],
                                ),
                                child: Center(child: WeuTubeBrand(
                                  size: widget.compact ? 31 : 39)),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: widget.compact ? 14 : 19,
                          left: 10,
                          right: 10,
                          child: Opacity(
                            opacity: ((t - .45) / .55).clamp(0.0, 1.0),
                            child: const Text(
                              'WATCH  /  CREATE  /  BELONG',
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFDBE3F2),
                                fontSize: 10,
                                letterSpacing: 2.05,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _storyCard({
    required double left,
    required double top,
    required double rotation,
    required String title,
    required IconData icon,
    required Color accent,
    required double progress,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: Opacity(
        opacity: ((progress - .04) / .42).clamp(0.0, 1.0),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .001)
            ..rotateY(rotation)
            ..rotateZ(rotation * .34),
          child: Container(
            width: 111,
            height: widget.compact ? 72 : 87,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF233C69),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF61759B)),
              boxShadow: const [
                BoxShadow(color: Color(0x66030E29),
                  blurRadius: 13, offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon, color: accent, size: 18),
                  const SizedBox(width: 5),
                  Expanded(child: Text(title, maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9, letterSpacing: .7,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFEDF1F9)))),
                ]),
                const Spacer(),
                Row(children: [
                  Container(height: 15, width: 17,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .65),
                      borderRadius: BorderRadius.circular(4))),
                  const SizedBox(width: 5),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 4, decoration: BoxDecoration(
                        color: const Color(0xFFD3DFF0),
                        borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 4),
                      FractionallySizedBox(widthFactor: .63,
                        child: Container(height: 4, decoration: BoxDecoration(
                          color: const Color(0xFF7D92B9),
                          borderRadius: BorderRadius.circular(4)))),
                    ],
                  )),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SceneLines extends CustomPainter {
  const _SceneLines({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .52);
    final ring = Rect.fromCenter(center: center,
      width: math.min(size.width * .97, 460.0), height: size.height * .58);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawArc(ring, math.pi * .83, math.pi * 1.45, false,
      base..color = const Color(0xFF5B739F));
    canvas.drawArc(ring, -math.pi * .84,
      math.pi * (.16 + .89 * progress), false,
      base..color = coral);
    canvas.drawArc(ring, math.pi * .19, math.pi * .42, false,
      base..color = const Color(0xFFD5E0F5));
    canvas.drawCircle(Offset(center.dx - ring.width * .47, center.dy + 4),
      3.8, Paint()..color = const Color(0xFFDBE4F4));
    canvas.drawCircle(Offset(center.dx + ring.width * .48, center.dy - 7),
      3.8, Paint()..color = const Color(0xFFFF6A57));
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 5; col++) {
        canvas.drawCircle(
          Offset(17 + col * 9.0, size.height - 40 - row * 9.0), .9,
          Paint()..color = const Color(0xFF526B95));
        canvas.drawCircle(
          Offset(size.width - 17 - col * 9.0, 23 + row * 9.0), .9,
          Paint()..color = const Color(0xFF526B95));
      }
    }
  }

  @override
  bool shouldRepaint(_SceneLines old) => old.progress != progress;
}

/// No duplicated brand wordmark or large static splash text below the scene.
class PremiumSignInHeader extends StatelessWidget {
  const PremiumSignInHeader({super.key, required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ImmersiveBrandHero(compact: compact),
      SizedBox(height: compact ? 15 : 21),
      const Text('Welcome Back',
        textAlign: TextAlign.center,
        style: TextStyle(color: navy, fontSize: 26,
          height: 1.08, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      const Text('Your stories. Our community.',
        textAlign: TextAlign.center,
        style: TextStyle(color: slate, fontSize: 14,
          height: 1.35, fontWeight: FontWeight.w600)),
    ],
  );
}
