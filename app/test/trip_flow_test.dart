import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip/app.dart';
import 'package:safetrip/features/auth/data/mock_auth_repository.dart';
import 'package:safetrip/features/profile/data/mock_profile_repository.dart';
import 'package:safetrip/features/trips/data/mock_trip_repository.dart';

Future<void> signIn(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = MockAuthRepository();
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  await tester.pumpWidget(
    SafeTripApp(
      authRepository: auth,
      profileRepository: MockProfileRepository(auth),
      tripRepository: MockTripRepository(),
      demoMode: true,
      showIntro: false,
      initialSearchDate: tomorrow,
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

Future<void> choose(WidgetTester tester, Key field, String label) async {
  await tester.tap(find.byKey(field));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a driver publishes a trip, finds it, then cancels it', (
    tester,
  ) async {
    await signIn(tester);
    await tester.tap(find.byKey(const Key('nav_trips')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trips_need_driver')), findsOneWidget);

    await tester.tap(find.byKey(const Key('trips_enable_driver')));
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
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('trip_publish')));
    await tester.pumpAndSettle();
    await choose(tester, const Key('trip_from'), 'Tunis');
    await choose(tester, const Key('trip_to'), 'Nabeul');
    await tester.ensureVisible(find.byKey(const Key('trip_submit')));
    await tester.tap(find.byKey(const Key('trip_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Tunis → Nabeul'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav_home')));
    await tester.pumpAndSettle();
    await choose(tester, const Key('search_from'), 'Tunis');
    await choose(tester, const Key('search_to'), 'Nabeul');
    await tester.ensureVisible(find.byKey(const Key('search_submit')));
    await tester.tap(find.byKey(const Key('search_submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search_empty')), findsNothing);
    expect(find.text('Tunis → Nabeul'), findsWidgets);
    expect(find.textContaining('123 TU'), findsNothing);

    await tester.tap(find.text('Tunis → Nabeul').first);
    await tester.pumpAndSettle();
    expect(
      find.text('Le matricule du véhicule n\'est jamais affiché ici.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('trip_cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trip_cancel_confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav_trips')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Annulé'), findsOneWidget);
  });
}
