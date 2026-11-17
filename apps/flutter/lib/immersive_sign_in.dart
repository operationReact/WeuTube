import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'product_ui.dart' show WeuTubeBrand, navy, coral, slate;

/// WeuTube's existing SVG logo is the sole brand image throughout this motion.
/// The three-dimensional depth belongs to the stage, orbiting cards and shadows;
/// the approved icon and lettering are never redrawn, recolored or distorted.
class ImmersiveBrandHero extends StatefulWidget {
  const ImmersiveBrandHero({super.key, this.compact = false});
  final bool compact;
  @override
  State<ImmersiveBrandHero> createState() => _ImmersiveBrandHeroState();
}

class _ImmersiveBrandHeroState extends State<ImmersiveBrandHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 2050));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
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

  @override
  Widget build(BuildContext context) {
    final motionOff = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final height = widget.compact ? 238.0 : 292.0;
    return Semantics(
      label: 'WeuTube brand — Watch, create, share and grow',
      child: RepaintBoundary(
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: AnimatedBuilder(
            animation: _intro,
            builder: (context, _) {
              final t = motionOff ? 1.0 : Curves.easeOutCubic.transform(_intro.value);
              final settle = math.min(1.0, math.max(0.0, (t - .35) / .65));
              return LayoutBuilder(builder: (context, limits) {
                final w = limits.maxWidth;
                final center = w / 2;
                final ellipseY = height * .46;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      const Positioned.fill(child: ColoredBox(color: Color(0xFF10244A))),
                      Positioned.fill(child: CustomPaint(
                        painter: _OrbitPainter(progress: t),
                      )),
                      // Perspective stage. Its geometry is independent of the logo.
                      Positioned(
                        left: center - 131, top: height * .69,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, .0012)
                            ..rotateX(-.48),
                          child: Container(
                            width: 262, height: 58,
                            decoration: BoxDecoration(
                              color: const Color(0xFF526591),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: const Color(0xFFBCC6E0), width: 2),
                              boxShadow: const [
                                BoxShadow(color: Color(0x6E071229),
                                  blurRadius: 24, offset: Offset(0, 22)),
                              ],
                            ),
                            child: Center(child: Container(
                              height: 24, width: 220,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDAE1F1),
                                borderRadius: BorderRadius.circular(100)),
                            )),
                          ),
                        ),
                      ),
                      _satellite(center, ellipseY, t, 0, Icons.play_arrow_rounded),
                      _satellite(center, ellipseY, t, 1, Icons.videocam_outlined),
                      _satellite(center, ellipseY, t, 2, Icons.people_outline_rounded),
                      _satellite(center, ellipseY, t, 3, Icons.bar_chart_rounded),
                      // The approved source SVG is rendered unchanged on a floating card.
                      Positioned(
                        left: center - math.min(w * .37, 170),
                        width: math.min(w * .74, 340),
                        top: height * (.335 + .085 * (1 - settle)),
                        child: Opacity(
                          opacity: math.max(0, (t - .22) / .25).clamp(0.0, 1.0),
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, .0006)
                              ..rotateY(.09 * (1 - settle))
                              ..translate(0.0, -2.5 * settle, 0.0),
                            child: Container(
                              height: widget.compact ? 73 : 88,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(21),
                                border: Border.all(color: const Color(0xFFE5E8F0)),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x5E030E27),
                                    blurRadius: 21, offset: Offset(0, 15)),
                                ],
                              ),
                              child: const Center(child: WeuTubeBrand(size: 37)),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 10, right: 14,
                        child: Text('WATCH  •  CREATE  •  SHARE  •  GROW',
                          style: TextStyle(fontSize: 9,
                            color: Colors.white.withValues(alpha: .78),
                            letterSpacing: 1.25, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _satellite(double cx, double cy, double t, int index, IconData icon) {
    final phase = index * math.pi / 2 + .46 + (.68 * (1 - t));
    final rx = widget.compact ? 129.0 : 151.0;
    final x = cx + math.cos(phase) * rx - 20;
    final y = cy + math.sin(phase) * (widget.compact ? 61.0 : 72.0) - 20;
    final depth = .83 + (.16 * (math.sin(phase) + 1) / 2);
    final col = index.isEven ? coral : const Color(0xFFC0CEE9);
    return Positioned(
      left: x, top: y + 13 * (1 - t),
      child: Opacity(
        opacity: math.max(0, (t - .08) / .4).clamp(0, 1),
        child: Transform.scale(
          scale: depth,
          child: Transform.rotate(
            angle: (index.isEven ? -.11 : .11) * (1 - t),
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: const Color(0xFFF9FAFD),
                border: Border.all(color: const Color(0xFFE0E6F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x66040C24),
                    blurRadius: 13, offset: Offset(0, 7)),
                ],
              ),
              child: Icon(icon, size: 23, color: col),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .47);
    final area = Rect.fromCenter(center: center,
      width: math.min(size.width * .94, 375), height: size.height * .45);
    final base = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.8;
    canvas.drawArc(area, -.3, math.pi * 1.8, false,
      base..color = const Color(0xFF526C9B));
    canvas.drawArc(area, -math.pi * .85 + progress * .35,
      math.pi * (.12 + .7 * progress), false,
      base..color = const Color(0xFFFE3F23));
    canvas.drawArc(area, math.pi * .16,
      math.pi * (.2 + .42 * progress), false,
      base..color = const Color(0xFFB0CDF8));
    final anchor = Offset(center.dx, size.height * .71);
    canvas.drawOval(Rect.fromCenter(center: anchor,
      width: math.min(size.width * .77, 310), height: 22),
      Paint()..color = const Color(0x5B030E2E));
    final pin = Paint()..color = const Color(0xFFFF7B63);
    canvas.drawCircle(Offset(center.dx + area.width * .43, center.dy - 5), 4, pin);
    canvas.drawCircle(Offset(center.dx - area.width * .44, center.dy + 7), 3.5,
      Paint()..color = const Color(0xFFCDDDF5));
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.progress != progress;
}

/// The complete first impression: animation, positioning and product purpose.
class PremiumSignInHeader extends StatelessWidget {
  const PremiumSignInHeader({super.key, required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ImmersiveBrandHero(compact: compact),
      const SizedBox(height: 21),
      const Text('Welcome Back', textAlign: TextAlign.center,
        style: TextStyle(color: navy, fontSize: 31,
          height: 1.12, fontWeight: FontWeight.w900)),
      const SizedBox(height: 7),
      const Text('Your stories. Our community.',
        textAlign: TextAlign.center,
        style: TextStyle(color: navy, fontSize: 17,
          height: 1.28, fontWeight: FontWeight.w700)),
      const SizedBox(height: 5),
      const Text('Watch, create, share and grow together.',
        textAlign: TextAlign.center,
        style: TextStyle(color: slate, fontSize: 13, height: 1.4)),
    ],
  );
}
