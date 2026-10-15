import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/safetrip_logo.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    required this.onFinished,
    this.playSound = true,
  });

  final VoidCallback onFinished;
  final bool playSound;

  static const duration = Duration(milliseconds: 3200);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: SplashPage.duration,
  );
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();
  AudioPlayer? _player;

  Animation<double> _interval(
    double begin,
    double end, [
    Curve curve = Curves.easeOutCubic,
  ]) => CurvedAnimation(
    parent: _intro,
    curve: Interval(begin, end, curve: curve),
  );

  late final _bgZoom = Tween(
    begin: 1.12,
    end: 1.0,
  ).animate(_interval(0, 1, Curves.easeOut));
  late final _logo = _interval(0.05, 0.4, Curves.elasticOut);
  late final _logoFade = _interval(0.05, 0.2);
  late final _title = _interval(0.22, 0.45);
  late final _tagline = _interval(0.35, 0.58);
  late final _loader = _interval(0.5, 0.7);

  @override
  void initState() {
    super.initState();
    _intro.forward().whenComplete(widget.onFinished);
    if (widget.playSound) {
      Future<void>.delayed(const Duration(milliseconds: 250), _playChime);
    }
  }

  Future<void> _playChime() async {
    try {
      final player = _player = AudioPlayer();
      await player.play(AssetSource('sounds/welcome.wav'), volume: 0.7);
    } catch (_) {
      // Browsers block autoplay and some devices have no audio output:
      // the splash must never fail because of the sound.
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final logoSize = math.min(size.width * 0.34, 150.0);

    return Scaffold(
      backgroundColor: const Color(0xFFDCEBFF),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _bgZoom,
            builder: (_, child) =>
                Transform.scale(scale: _bgZoom.value, child: child),
            child: Image.asset(
              'assets/images/splash_bg.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.45, 0.7, 1],
                colors: [
                  Color(0x88FFFFFF),
                  Color(0x22FFFFFF),
                  Color(0x00000000),
                  Color(0x99000000),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: size.height * 0.08),
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logo,
                    child: _GlowPulse(
                      animation: _loop,
                      child: SafeTripLogo(size: logoSize),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _SlideFade(
                  animation: _title,
                  child: SafeTripWordmark(fontSize: logoSize * 0.38),
                ),
                const SizedBox(height: 12),
                _SlideFade(
                  animation: _tagline,
                  offset: 12,
                  child: Text(
                    'Voyagez ensemble, en toute sécurité',
                    style: TextStyle(
                      fontSize: 17,
                      color: AppColors.primaryDark.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                FadeTransition(
                  opacity: _loader,
                  child: Column(
                    children: [
                      _ArcLoader(animation: _loop),
                      const SizedBox(height: 18),
                      const Text(
                        'Préparation de votre expérience...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(blurRadius: 8, color: Colors.black45),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      _BouncingDots(animation: _loop),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideFade extends StatelessWidget {
  const _SlideFade({
    required this.animation,
    required this.child,
    this.offset = 24,
  });

  final Animation<double> animation;
  final Widget child;
  final double offset;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) => Opacity(
        opacity: animation.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - animation.value) * offset),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _GlowPulse extends StatelessWidget {
  const _GlowPulse({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) {
        final t = math.sin(animation.value * math.pi * 2) * 0.5 + 0.5;
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.18 + 0.17 * t),
                blurRadius: 30 + 20 * t,
                spreadRadius: 2 + 6 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: child,
    );
  }
}

class _ArcLoader extends StatelessWidget {
  const _ArcLoader({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: animation,
      child: CustomPaint(size: const Size.square(46), painter: _ArcPainter()),
    );
  }
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawArc(
      rect.deflate(3),
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawArc(
      rect.deflate(3),
      0,
      math.pi * 1.3,
      false,
      Paint()
        ..shader = const SweepGradient(
          colors: [Color(0x0016A34A), AppColors.green, Color(0xFF4ADE80)],
          stops: [0, 0.5, 0.65],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BouncingDots extends StatelessWidget {
  const _BouncingDots({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final phase = (animation.value - i * 0.18) % 1.0;
          final lift = math.max(0.0, math.sin(phase * math.pi * 2));
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Transform.translate(
              offset: Offset(0, -6 * lift),
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(
                    Colors.white70,
                    const Color(0xFF4ADE80),
                    lift,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
