import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip/app.dart';
import 'package:safetrip/features/admin/data/mock_admin_repository.dart';
import 'package:safetrip/features/auth/data/mock_auth_repository.dart';
import 'package:safetrip/features/profile/data/mock_profile_repository.dart';
import 'package:safetrip/features/trips/data/mock_trip_repository.dart';

void main() {
  testWidgets('demo admin opens the admin space and sees users', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = MockAuthRepository();
    final trips = MockTripRepository();
    final profiles = MockProfileRepository(auth)..trips = trips;
    final admin = MockAdminRepository(profiles: profiles, trips: trips);
    await tester.pumpWidget(
      SafeTripApp(
        authRepository: auth,
        profileRepository: profiles,
        tripRepository: trips,
        adminRepository: admin,
        demoMode: true,
        showIntro: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('login_email')),
      MockAuthRepository.demoEmail,
    );
    await tester.enterText(
      find.byKey(const Key('login_password')),
      MockAuthRepository.demoPassword,
    );
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav_profile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menu_admin')), findsOneWidget);
    await tester.tap(find.byKey(const Key('menu_admin')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin_users')), findsOneWidget);
    expect(find.textContaining('Amine'), findsWidgets);
  });
}
