import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/home/home_page.dart';

class SafeTripApp extends StatelessWidget {
  const SafeTripApp({
    super.key,
    required this.authRepository,
    this.demoMode = false,
  });

  final AuthRepository authRepository;
  final bool demoMode;

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
        home: AuthGate(demoMode: demoMode),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.demoMode = false});

  final bool demoMode;

  @override
  Widget build(BuildContext context) {
    switch (context.watch<AuthController>().status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.authenticated:
        return const HomePage();
      case AuthStatus.unauthenticated:
        return LoginPage(demoMode: demoMode);
    }
  }
}
