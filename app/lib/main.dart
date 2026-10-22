import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/firebase_auth_repository.dart';
import 'features/auth/data/mock_auth_repository.dart';
import 'firebase_options.dart';

/// `flutter run --dart-define=USE_FIREBASE=true` once `flutterfire configure`
/// has generated `lib/firebase_options.dart`. Otherwise the app runs in demo
/// mode with an in-memory account store.
const useFirebase = bool.fromEnvironment('USE_FIREBASE');

/// `--dart-define=REQUIRE_PHONE=true` adds the SMS code step after the
/// e-mail verification (needs Phone sign-in working in Firebase).
const requirePhone = bool.fromEnvironment('REQUIRE_PHONE');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AuthRepository repository;
  if (useFirebase) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    repository = FirebaseAuthRepository();
  } else {
    repository = MockAuthRepository();
  }

  runApp(
    SafeTripApp(
      authRepository: repository,
      demoMode: !useFirebase,
      requirePhoneVerification: requirePhone,
    ),
  );
}
