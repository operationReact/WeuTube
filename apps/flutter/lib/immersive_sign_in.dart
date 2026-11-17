import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'product_ui.dart' show WeuTubeBrand, navy, coral, slate;

/// One unbroken white sign-in canvas. These very subtle threads originate
/// at the logo and continue beside the authentication controls; neither the
/// logo nor the form is enclosed in an isolated decorative section.
class ImmersiveSignInCanvas extends StatelessWidget {
  const ImmersiveSignInCanvas({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    key: const ValueKey('immersive-signin-canvas'),
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(painter: const _ContinuousCanvasPainter()),
        ),
      ),
      child,
    ],
  );
}

class _ContinuousCanvasPainter extends CustomPainter {
  const _ContinuousCanvasPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final left = Path()
      ..moveTo(w * .16, 52)
      ..cubicTo(-14, 115, 9, 174, 11, 248)
      ..cubicTo(11, 334, -1, 440, 10, math.min(h - 24, 650));
    final right = Path()
      ..moveTo(w * .84, 50)
      ..cubicTo(w + 15, 122, w - 6, 189, w - 11, 253)
      ..cubicTo(w - 17, 350, w + 3, 431,
        w - 11, math.min(h - 24, 650));
    canvas.drawPath(left, Paint()
      ..color = const Color(0x1B031B4B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25);
    canvas.drawPath(right, Paint()
      ..color = const Color(0x28FE3F23)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35);
    final pin = Paint()..color = const Color(0x70FE3F23);
    canvas.drawCircle(Offset(w - 11, math.min(h - 35, 355)), 2.8, pin);
    canvas.drawCircle(Offset(11, math.min(h - 35, 270)), 2.4,
      Paint()..color = const Color(0x50031B4B));
  }

  @override
  bool shouldRepaint(_ContinuousCanvasPainter old) => false;
}

/// The master SVG is rendered directly over the page, never on a white
/// placard, a navy hero box or any other decorative container. Perspective
/// affects ONLY the small video/community layers around the logo.
class ImmersiveBrandHero extends StatefulWidget {
  const ImmersiveBrandHero({super.key, this.compact = false});
  final bool compact;

  @override
  State<ImmersiveBrandHero> createState() => _ImmersiveBrandHeroState();
}

class _ImmersiveBrandHeroState extends State<ImmersiveBrandHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1450),
  );
  double _parallax = 0;

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion) {
      _entrance.value = 1;
    } else if (_entrance.value == 0 && !_entrance.isAnimating) {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _replay() {
    if (!_reduceMotion) _entrance.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.compact ? 160.0 : 188.0;
    return Semantics(
      label: 'WeuTube logo. Tap to replay its welcome motion.',
      button: true,
      child: RepaintBoundary(
        child: GestureDetector(
          key: const ValueKey('immersive-brand-hero'),
          behavior: HitTestBehavior.opaque,
          onTap: _replay,
          onHorizontalDragUpdate: _reduceMotion ? null : (details) {
            setState(() {
              _parallax = (_parallax + details.delta.dx / 240)
                  .clamp(-.15, .15);
            });
          },
          onHorizontalDragEnd: _reduceMotion ? null : (_) {
            setState(() => _parallax = 0);
          },
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: AnimatedBuilder(
              animation: _entrance,
              builder: (context, _) {
                final t = _reduceMotion ? 1.0
                    : Curves.easeOutCubic.transform(_entrance.value);
                return LayoutBuilder(builder: (context, layout) {
                  final w = layout.maxWidth;
                  final small = w < 330;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(child: IgnorePointer(
                        child: CustomPaint(
                          painter: _LogoOrbitPainter(progress: t),
                        ),
                      )),
                      Positioned(
                        top: widget.compact ? 17 : 20,
                        left: math.max(7.0, w * .075) + _parallax * 24,
                        child: _floatingVideo(
                          progress: t,
                          icon: Icons.video_library_outlined,
                          color: const Color(0xFF183666),
                          angle: -.17,
                          title: 'WATCH',
                        ),
                      ),
                      Positioned(
                        top: widget.compact ? 11 : 16,
                        right: math.max(7.0, w * .08) + _parallax * 24,
                        child: _floatingVideo(
                          progress: t,
                          icon: Icons.people_outline_rounded,
                          color: coral,
                          angle: .16,
                          title: 'CREATE',
                        ),
                      ),
                      Positioned(
                        top: widget.compact ? 79 : 91,
                        left: 0, right: 0,
                        child: Opacity(
                          opacity: ((t - .13) / .44).clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, 8 * (1 - t)),
                            child: Center(
                              child: SizedBox(
                                width: math.min(w * .89, 344.0),
                                height: small ? 46 : 56,
                                child: Center(child: WeuTubeBrand(
                                  size: small ? 39 : 48)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _floatingVideo({
    required double progress,
    required IconData icon,
    required Color color,
    required double angle,
    required String title,
  }) {
    final show = ((progress - .02) / .58).clamp(0.0, 1.0);
    final width = widget.compact ? 72.0 : 84.0;
    return Opacity(
      opacity: show,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .0013)
          ..rotateY(angle * .9)
          ..rotateZ(angle * (1 + (1 - show) * .8)),
        child: Container(
          width: width,
          height: widget.compact ? 62 : 70,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFFBFCFF),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0xFFDCE4EF)),
            boxShadow: const [
              BoxShadow(color: Color(0x16031B4B),
                blurRadius: 15, offset: Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 28,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 15,
                  color: Colors.white),
              ),
              const SizedBox(height: 5),
              Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: navy, fontSize: 9,
                  letterSpacing: .6, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoOrbitPainter extends CustomPainter {
  const _LogoOrbitPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .55);
    final ring = Rect.fromCenter(
      center: center,
      width: math.min(size.width * .96, 490.0),
      height: size.height * .73,
    );
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawArc(ring, math.pi * .74, math.pi * 1.5, false,
      base..color = const Color(0x2D031B4B));
    canvas.drawArc(ring, -math.pi * .8,
      math.pi * (.12 + progress * .8), false,
      base..color = const Color(0x8CFE3F23));
    canvas.drawCircle(Offset(center.dx - ring.width * .48, center.dy + 4),
      3.0, Paint()..color = const Color(0x66031B4B));
    canvas.drawCircle(Offset(center.dx + ring.width * .47, center.dy - 6),
      3.0, Paint()..color = const Color(0xA0FE3F23));
  }

  @override
  bool shouldRepaint(_LogoOrbitPainter old) =>
      old.progress != progress;
}

class PremiumSignInHeader extends StatelessWidget {
  const PremiumSignInHeader({super.key, required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ImmersiveBrandHero(compact: compact),
      const SizedBox(height: 3),
      const Text('Welcome Back',
        textAlign: TextAlign.center,
        style: TextStyle(color: navy, fontSize: 25,
          height: 1.1, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      const Text('Your stories. Our community.',
        textAlign: TextAlign.center,
        style: TextStyle(color: slate, fontSize: 14,
          height: 1.3, fontWeight: FontWeight.w600)),
    ],
  );
}
