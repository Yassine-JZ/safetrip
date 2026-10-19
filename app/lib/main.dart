import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'features/admin/data/admin_repository.dart';
import 'features/admin/data/firebase_admin_repository.dart';
import 'features/admin/data/mock_admin_repository.dart';
import 'features/admin/data/push_service.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/firebase_auth_repository.dart';
import 'features/auth/data/mock_auth_repository.dart';
import 'features/profile/data/firebase_profile_repository.dart';
import 'features/profile/data/mock_profile_repository.dart';
import 'features/profile/data/profile_repository.dart';
import 'features/sos/data/location_service.dart';
import 'features/trips/data/firebase_trip_repository.dart';
import 'features/trips/data/mock_trip_repository.dart';
import 'features/trips/data/trip_repository.dart';
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

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final TripRepository tripRepository;
  final AdminRepository adminRepository;
  final LocationService locationService;
  PushService? pushService;

  if (useFirebase) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    authRepository = FirebaseAuthRepository();
    profileRepository = FirebaseProfileRepository();
    tripRepository = FirebaseTripRepository();
    adminRepository = FirebaseAdminRepository();
    locationService = DeviceLocationService();
    pushService = PushService(admin: adminRepository, trips: tripRepository);
  } else {
    final demo = MockAuthRepository();
    final trips = MockTripRepository();
    final profiles = MockProfileRepository(demo)..trips = trips;
    authRepository = demo;
    profileRepository = profiles;
    tripRepository = trips;
    adminRepository = MockAdminRepository(profiles: profiles, trips: trips);
    locationService = MockLocationService(); // Tunis centre, pour la démo
  }

  runApp(
    SafeTripApp(
      authRepository: authRepository,
      profileRepository: profileRepository,
      tripRepository: tripRepository,
      adminRepository: adminRepository,
      locationService: locationService,
      pushService: pushService,
      demoMode: !useFirebase,
      requirePhoneVerification: requirePhone,
    ),
  );
}
