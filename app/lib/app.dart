import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/admin/data/admin_repository.dart';
import 'features/admin/data/null_admin_repository.dart';
import 'features/admin/data/push_service.dart';
import 'features/admin/presentation/suspended_page.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/verify_email_page.dart';
import 'features/auth/presentation/verify_phone_page.dart';
import 'features/home/app_shell.dart';
import 'features/intro/intro_flow.dart';
import 'features/profile/data/profile_models.dart';
import 'features/profile/data/profile_repository.dart';
import 'features/sos/data/location_service.dart';
import 'features/trips/data/trip_repository.dart';

class SafeTripApp extends StatelessWidget {
  const SafeTripApp({
    super.key,
    required this.authRepository,
    required this.profileRepository,
    required this.tripRepository,
    AdminRepository? adminRepository,
    LocationService? locationService,
    this.pushService,
    this.demoMode = false,
    this.initialSearchDate,
    this.showIntro = true,
    this.requirePhoneVerification = false,
  }) : adminRepository = adminRepository ?? const NullAdminRepository(),
       locationService = locationService ?? const MockLocationService();

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final TripRepository tripRepository;
  final AdminRepository adminRepository;
  final LocationService locationService;
  final PushService? pushService;
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
      pushService: pushService,
    );
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController(authRepository)),
        Provider<ProfileRepository>.value(value: profileRepository),
        Provider<TripRepository>.value(value: tripRepository),
        Provider<AdminRepository>.value(value: adminRepository),
        Provider<LocationService>.value(value: locationService),
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

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.demoMode = false,
    this.requirePhoneVerification = false,
    this.initialSearchDate,
    this.pushService,
  });

  final bool demoMode;
  final bool requirePhoneVerification;
  final DateTime? initialSearchDate;
  final PushService? pushService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _pushUid;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.authenticated:
        if (!auth.emailVerified) {
          return VerifyEmailPage(demoMode: widget.demoMode);
        }
        if (widget.requirePhoneVerification && !auth.phoneVerified) {
          return VerifyPhonePage(demoMode: widget.demoMode);
        }
        final uid = auth.user!.uid;
        return StreamBuilder<UserProfile?>(
          stream: context.read<ProfileRepository>().watchProfile(uid),
          builder: (context, snapshot) {
            final profile = snapshot.data;
            if (profile?.suspended == true) {
              return const SuspendedPage();
            }
            final push = widget.pushService;
            if (push != null && _pushUid != uid) {
              _pushUid = uid;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                push.start(uid);
              });
            }
            return AppShell(initialSearchDate: widget.initialSearchDate);
          },
        );
      case AuthStatus.unauthenticated:
        if (_pushUid != null) {
          widget.pushService?.stop();
          _pushUid = null;
        }
        return LoginPage(demoMode: widget.demoMode);
    }
  }
}
