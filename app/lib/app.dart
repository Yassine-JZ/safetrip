import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/verify_email_page.dart';
import 'features/auth/presentation/verify_phone_page.dart';
import 'features/home/app_shell.dart';
import 'features/intro/intro_flow.dart';
import 'features/profile/data/profile_repository.dart';
import 'features/trips/data/trip_repository.dart';

class SafeTripApp extends StatelessWidget {
  const SafeTripApp({
    super.key,
    required this.authRepository,
    required this.profileRepository,
    required this.tripRepository,
    this.demoMode = false,
    this.initialSearchDate,
    this.showIntro = true,
    this.requirePhoneVerification = false,
  });

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final TripRepository tripRepository;
  final bool demoMode;
  final DateTime? initialSearchDate;
  final bool showIntro;

  /// SMS step after the e-mail one. Off until SMS sending works on the
  /// Firebase project.
  final bool requirePhoneVerification;

  @override
  Widget build(BuildContext context) {
    final gate = AuthGate(
      demoMode: demoMode,
      requirePhoneVerification: requirePhoneVerification,
      initialSearchDate: initialSearchDate,
    );
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController(authRepository)),
        Provider<ProfileRepository>.value(value: profileRepository),
        Provider<TripRepository>.value(value: tripRepository),
      ],
      child: MaterialApp(
        title: 'SafeTrip',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr'), Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: showIntro ? IntroFlow(child: gate) : gate,
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    this.demoMode = false,
    this.requirePhoneVerification = false,
    this.initialSearchDate,
  });

  final bool demoMode;
  final bool requirePhoneVerification;
  final DateTime? initialSearchDate;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.authenticated:
        if (!auth.emailVerified) return VerifyEmailPage(demoMode: demoMode);
        if (requirePhoneVerification && !auth.phoneVerified) {
          return VerifyPhonePage(demoMode: demoMode);
        }
        return AppShell(initialSearchDate: initialSearchDate);
      case AuthStatus.unauthenticated:
        return LoginPage(demoMode: demoMode);
    }
  }
}
