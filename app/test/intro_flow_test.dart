import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip/app.dart';
import 'package:safetrip/features/auth/data/mock_auth_repository.dart';
import 'package:safetrip/features/profile/data/mock_profile_repository.dart';
import 'package:safetrip/features/intro/splash_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget demoApp() {
  final auth = MockAuthRepository();
  return SafeTripApp(
    authRepository: auth,
    profileRepository: MockProfileRepository(auth),
    demoMode: true,
  );
}

Future<void> settle(WidgetTester tester, [int frames = 15]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('splash, onboarding on first launch, then login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(demoApp());
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Voyagez ensemble, en toute sécurité'), findsOneWidget);

    await tester.pump(SplashPage.duration);
    await settle(tester);
    expect(find.text('Passer'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_next')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await settle(tester);
    expect(find.text('Commencer'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_next')));
    await settle(tester);
    expect(find.text('Bon retour !'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_seen'), isTrue);
  });

  testWidgets('onboarding is skipped once seen', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_seen': true});
    await tester.pumpWidget(demoApp());
    await tester.pump(SplashPage.duration);
    await settle(tester);
    expect(find.text('Passer'), findsNothing);
    expect(find.text('Bon retour !'), findsOneWidget);
  });
}
