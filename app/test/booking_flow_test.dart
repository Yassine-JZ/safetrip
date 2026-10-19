import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip/app.dart';
import 'package:safetrip/features/auth/data/mock_auth_repository.dart';
import 'package:safetrip/features/profile/data/mock_profile_repository.dart';
import 'package:safetrip/features/trips/data/mock_trip_repository.dart';

Future<void> choose(WidgetTester tester, Key field, String label) async {
  await tester.tap(find.byKey(field));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a passenger books, the driver accepts, then runs the trip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = MockAuthRepository();
    final trips = MockTripRepository();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await tester.pumpWidget(
      SafeTripApp(
        authRepository: auth,
        profileRepository: MockProfileRepository(auth)..trips = trips,
        tripRepository: trips,
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

    await tester.tap(find.byKey(const Key('nav_trips')));
    await tester.pumpAndSettle();
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

    await tester.tap(find.byKey(const Key('nav_profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('go_register')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('register_first_name')),
      'Salma',
    );
    await tester.enterText(
      find.byKey(const Key('register_last_name')),
      'Trabelsi',
    );
    await tester.enterText(
      find.byKey(const Key('register_email')),
      'salma@univ.tn',
    );
    await tester.enterText(find.byKey(const Key('register_phone')), '55000111');
    await tester.enterText(
      find.byKey(const Key('register_password')),
      'Safe2026',
    );
    await tester.enterText(
      find.byKey(const Key('register_confirm')),
      'Safe2026',
    );
    await tester.ensureVisible(find.byKey(const Key('register_terms')));
    await tester.tap(find.byKey(const Key('register_terms')));
    await tester.tap(find.byKey(const Key('register_submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('verify_check')));
    await tester.pumpAndSettle();

    await choose(tester, const Key('search_from'), 'Tunis');
    await choose(tester, const Key('search_to'), 'Nabeul');
    await tester.ensureVisible(find.byKey(const Key('search_submit')));
    await tester.tap(find.byKey(const Key('search_submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tunis → Nabeul'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trip_start')), findsNothing);
    await tester.tap(find.byKey(const Key('reserve_open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reserve_confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav_bookings')));
    await tester.pumpAndSettle();
    expect(find.text('En attente'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav_profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout')));
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
    await tester.tap(find.byKey(const Key('nav_trips')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tunis → Nabeul'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accepter'));
    await tester.pumpAndSettle();
    expect(find.text('Salma Trabelsi'), findsOneWidget);
    expect(find.byKey(const Key('no_passengers')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('trip_chat')));
    await tester.tap(find.byKey(const Key('trip_chat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat_empty')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('chat_input')),
      'RDV devant la fac',
    );
    await tester.tap(find.byKey(const Key('chat_send')));
    await tester.pumpAndSettle();
    expect(find.text('RDV devant la fac'), findsOneWidget);
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('trip_report')));
    await tester.tap(find.byKey(const Key('trip_report')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report_target')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salma Trabelsi').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('report_details')),
      'Test signalement démo',
    );
    await tester.tap(find.byKey(const Key('report_send')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Signalement envoyé'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('trip_start')));
    await tester.tap(find.byKey(const Key('trip_start')));
    await tester.pumpAndSettle();
    expect(find.text('En cours'), findsOneWidget);
    await tester.tap(find.byKey(const Key('trip_finish')));
    await tester.pumpAndSettle();
    expect(find.text('Terminé'), findsOneWidget);
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav_profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('login_email')), 'salma@univ.tn');
    await tester.enterText(find.byKey(const Key('login_password')), 'Safe2026');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav_alerts')));
    await tester.pumpAndSettle();
    expect(find.text('Demande acceptée'), findsOneWidget);
    expect(find.text('Nouveau message'), findsOneWidget);
    expect(find.text('Trajet démarré'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav_bookings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking_tile_trip-1')));
    await tester.pumpAndSettle();
    expect(find.text('Évaluer'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('star_demo-uid_4')));
    await tester.tap(find.byKey(const Key('star_demo-uid_4')));
    await tester.tap(find.byKey(const Key('rating_send_demo-uid')));
    await tester.pumpAndSettle();
    expect(find.text('Note envoyée'), findsOneWidget);
  });
}
