import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _Slide {
  const _Slide({
    required this.titleStart,
    required this.titleHighlight,
    required this.body,
    required this.image,
    required this.overlay,
  });

  final String titleStart;
  final String titleHighlight;
  final String body;
  final String image;
  final Widget Function(Animation<double> float) overlay;
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  final _controller = PageController();
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);
  double _page = 0;

  late final _slides = <_Slide>[
    _Slide(
      titleStart: 'Trouvez le trajet\nqui vous ',
      titleHighlight: 'convient',
      body:
          'Recherchez des trajets entre villes, à la date et au prix '
          'qui vous conviennent.',
      image: 'assets/images/onboarding_search.jpg',
      overlay: (f) => _Floating(
        animation: f,
        alignment: const Alignment(0, 0.95),
        child: const _SearchCard(),
      ),
    ),
    _Slide(
      titleStart: 'Voyagez ensemble\net ',
      titleHighlight: 'partagez les frais',
      body:
          'Économisez sur vos trajets en voyageant avec d\'autres '
          'étudiants de confiance.',
      image: 'assets/images/onboarding_together.jpg',
      overlay: (f) => _Floating(
        animation: f,
        alignment: const Alignment(-0.85, -0.85),
        child: const _Chip(icon: Icons.verified_user, label: 'Bonne route !'),
      ),
    ),
    _Slide(
      titleStart: 'Des trajets plus sûrs\navec ',
      titleHighlight: 'SafeTrip',
      body:
          'Réservations confirmées, bouton SOS pendant le trajet et '
          'assistance de l\'administration.',
      image: 'assets/images/onboarding_safety.jpg',
      overlay: (f) => _Floating(
        animation: f,
        alignment: const Alignment(1, -0.95),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _Chip(icon: Icons.event_seat, label: 'Places confirmées'),
            SizedBox(height: 8),
            _Chip(icon: Icons.sos, label: 'Bouton SOS'),
            SizedBox(height: 8),
            _Chip(icon: Icons.support_agent, label: 'Assistance'),
          ],
        ),
      ),
    ),
  ];

  bool get _isLast => _page.round() == _slides.length - 1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(
      () => setState(() => _page = _controller.page ?? 0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _float.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      widget.onFinished();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                SizedBox(
                  height: 48,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedOpacity(
                      opacity: _isLast ? 0 : 1,
                      duration: const Duration(milliseconds: 250),
                      child: TextButton(
                        key: const Key('onboarding_skip'),
                        onPressed: _isLast ? null : widget.onFinished,
                        child: const Text('Passer'),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    itemBuilder: (context, i) => _SlideView(
                      slide: _slides[i],
                      delta: _page - i,
                      float: _float,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
                  child: SizedBox(
                    height: 60,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: _isLast
                              ? Alignment.center
                              : Alignment.centerLeft,
                          child: _isLast
                              ? const SizedBox.shrink()
                              : _Dots(count: _slides.length, page: _page),
                        ),
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutBack,
                          alignment: _isLast
                              ? Alignment.center
                              : Alignment.centerRight,
                          child: _NextButton(
                            expanded: _isLast,
                            onPressed: _next,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({
    required this.slide,
    required this.delta,
    required this.float,
  });

  final _Slide slide;
  final double delta;
  final Animation<double> float;

  @override
  Widget build(BuildContext context) {
    final visibility = (1 - delta.abs()).clamp(0.0, 1.0);
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: AppColors.primaryDark,
      height: 1.2,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Transform.translate(
            offset: Offset(delta * 60, (1 - visibility) * 20),
            child: Opacity(
              opacity: visibility,
              child: Column(
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: slide.titleStart),
                        TextSpan(
                          text: slide.titleHighlight,
                          style: const TextStyle(color: AppColors.primary),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: titleStyle,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    slide.body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Transform.translate(
              offset: Offset(delta * -90, 0),
              child: Transform.scale(
                scale: 0.85 + 0.15 * visibility,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset(slide.image, fit: BoxFit.cover),
                        ),
                      ),
                      Positioned.fill(
                        child: Opacity(
                          opacity: math.pow(visibility, 3).toDouble(),
                          child: slide.overlay(float),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Floating extends StatelessWidget {
  const _Floating({
    required this.animation,
    required this.alignment,
    required this.child,
  });

  final Animation<double> animation;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, -8 * Curves.easeInOut.transform(animation.value)),
          child: child,
        ),
        child: child,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard();

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    return Container(
      width: 230,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row(Icons.trip_origin, 'Tunis'),
          row(Icons.location_on, 'Nabeul'),
          row(Icons.calendar_today, '15 oct. 2026 · 8 h'),
          const SizedBox(height: 6),
          Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text(
                  'Rechercher',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.page});

  final int count;
  final double page;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final t = (1 - (page - i).abs()).clamp(0.0, 1.0);
        return Container(
          margin: const EdgeInsets.only(right: 8),
          width: 10 + 18 * t,
          height: 10,
          decoration: BoxDecoration(
            color: Color.lerp(const Color(0xFFD4DCEB), AppColors.primary, t),
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.expanded, required this.onPressed});

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      width: expanded ? 240 : 60,
      height: 60,
      child: Material(
        color: AppColors.primary,
        elevation: 6,
        shadowColor: AppColors.primary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(expanded ? 18 : 30),
        child: InkWell(
          key: const Key('onboarding_next'),
          borderRadius: BorderRadius.circular(expanded ? 18 : 30),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (expanded)
                const Flexible(
                  child: Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Text(
                      'Commencer',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
