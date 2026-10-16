import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/verify_email_page.dart';
import 'features/auth/presentation/verify_phone_page.dart';
import 'features/home/home_page.dart';
import 'features/intro/intro_flow.dart';

class SafeTripApp extends StatelessWidget {
  const SafeTripApp({
    super.key,
    required this.authRepository,
    this.demoMode = false,
    this.showIntro = true,
  });

  final AuthRepository authRepository;
  final bool demoMode;
  final bool showIntro;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthController(authRepository),
      child: MaterialApp(
        title: 'SafeTrip',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr'), Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: showIntro
            ? IntroFlow(child: AuthGate(demoMode: demoMode))
            : AuthGate(demoMode: demoMode),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.demoMode = false});

  final bool demoMode;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.authenticated:
        if (!auth.emailVerified) return VerifyEmailPage(demoMode: demoMode);
        if (!auth.phoneVerified) return VerifyPhonePage(demoMode: demoMode);
        return const HomePage();
      case AuthStatus.unauthenticated:
        return LoginPage(demoMode: demoMode);
    }
  }
}
