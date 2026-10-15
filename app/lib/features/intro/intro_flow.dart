import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onboarding_page.dart';
import 'splash_page.dart';

enum _Phase { splash, onboarding, done }

/// Splash, then onboarding on first launch only, then [child].
class IntroFlow extends StatefulWidget {
  const IntroFlow({super.key, required this.child});

  final Widget child;

  static const _seenKey = 'onboarding_seen';

  @override
  State<IntroFlow> createState() => _IntroFlowState();
}

class _IntroFlowState extends State<IntroFlow> {
  _Phase _phase = _Phase.splash;
  final Future<SharedPreferences?> _prefs = SharedPreferences.getInstance()
      .then<SharedPreferences?>((p) => p)
      .catchError((Object _) => null);

  Future<void> _afterSplash() async {
    final prefs = await _prefs;
    final seen = prefs?.getBool(IntroFlow._seenKey) ?? false;
    if (!mounted) return;
    setState(() => _phase = seen ? _Phase.done : _Phase.onboarding);
  }

  Future<void> _afterOnboarding() async {
    setState(() => _phase = _Phase.done);
    final prefs = await _prefs;
    await prefs?.setBool(IntroFlow._seenKey, true);
  }

  @override
  Widget build(BuildContext context) {
    final Widget current = switch (_phase) {
      _Phase.splash => SplashPage(
        key: const ValueKey('splash'),
        onFinished: _afterSplash,
      ),
      _Phase.onboarding => OnboardingPage(
        key: const ValueKey('onboarding'),
        onFinished: _afterOnboarding,
      ),
      _Phase.done => KeyedSubtree(
        key: const ValueKey('app'),
        child: widget.child,
      ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 1.04, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: current,
    );
  }
}
