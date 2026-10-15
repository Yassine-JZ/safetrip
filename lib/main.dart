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

  runApp(SafeTripApp(authRepository: repository, demoMode: !useFirebase));
}
