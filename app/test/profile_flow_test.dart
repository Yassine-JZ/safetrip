import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip/app.dart';
import 'package:safetrip/features/auth/data/mock_auth_repository.dart';
import 'package:safetrip/features/profile/data/mock_profile_repository.dart';
import 'package:safetrip/features/profile/data/profile_models.dart';
import 'package:safetrip/features/trips/data/mock_trip_repository.dart';

Future<void> signIn(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = MockAuthRepository();
  await tester.pumpWidget(
    SafeTripApp(
      authRepository: auth,
      profileRepository: MockProfileRepository(auth),
      tripRepository: MockTripRepository(),
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
}

void main() {
  testWidgets('profile shows the private phone and edits the name', (
    tester,
  ) async {
    await signIn(tester);
    await tester.tap(find.byKey(const Key('nav_profile')));
    await tester.pumpAndSettle();
    expect(find.text('demo@safetrip.tn'), findsOneWidget);
    expect(find.text('Mode conducteur inactif'), findsOneWidget);

    await tester.tap(find.byKey(const Key('menu_info')));
    await tester.pumpAndSettle();
    expect(find.text('+216 98 111 222'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('profile_first_name')), 'Amin');
    await tester.tap(find.byKey(const Key('profile_save')));
    await tester.pumpAndSettle();
    expect(find.text('Amin Ben Salah'), findsOneWidget);
  });

  testWidgets('driver mode needs a vehicle and can be turned off', (
    tester,
  ) async {
    await signIn(tester);
    await tester.tap(find.byKey(const Key('nav_profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menu_driver')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('driver_brand')),
      'Peugeot 208',
    );
    await tester.enterText(
      find.byKey(const Key('driver_plate')),
      '123 tu 4567',
    );
    await tester.tap(find.byKey(const Key('driver_enable')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mode conducteur actif'), findsOneWidget);

    await tester.tap(find.byKey(const Key('driver_disable')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver_disable_confirm')));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.textContaining('Renseignez votre véhicule'), findsOneWidget);
    expect(find.text('123 TU 4567'), findsOneWidget);
  });

  testWidgets('deactivation is blocked while a booked trip exists', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = MockAuthRepository();
    final profiles = MockProfileRepository(auth)
      ..commitment = DriverCommitment.upcomingTripWithBookings;
    await tester.pumpWidget(
      SafeTripApp(
        authRepository: auth,
        profileRepository: profiles,
        tripRepository: MockTripRepository(),
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
    await tester.tap(find.byKey(const Key('menu_driver')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('driver_brand')),
      'Peugeot 208',
    );
    await tester.enterText(
      find.byKey(const Key('driver_plate')),
      '123 TU 4567',
    );
    await tester.tap(find.byKey(const Key('driver_enable')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('driver_disable')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver_disable_confirm')));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('driver_error')), findsOneWidget);
    expect(find.textContaining('Mode conducteur actif'), findsOneWidget);
  });
}
