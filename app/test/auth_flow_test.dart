import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip/app.dart';
import 'package:safetrip/features/auth/data/auth_repository.dart';
import 'package:safetrip/features/auth/data/mock_auth_repository.dart';
import 'package:safetrip/features/profile/data/mock_profile_repository.dart';
import 'package:safetrip/features/trips/data/mock_trip_repository.dart';

Future<void> pumpApp(WidgetTester tester, {bool requirePhone = false}) async {
  tester.view.physicalSize = const Size(1200, 1600);
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
      requirePhoneVerification: requirePhone,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> fillRegisterForm(
  WidgetTester tester, {
  required String firstName,
  required String lastName,
  required String email,
  required String phone,
  bool acceptTerms = true,
}) async {
  await tester.enterText(
    find.byKey(const Key('register_first_name')),
    firstName,
  );
  await tester.enterText(find.byKey(const Key('register_last_name')), lastName);
  await tester.enterText(find.byKey(const Key('register_email')), email);
  await tester.enterText(find.byKey(const Key('register_phone')), phone);
  await tester.enterText(
    find.byKey(const Key('register_password')),
    'Safe2026',
  );
  await tester.enterText(find.byKey(const Key('register_confirm')), 'Safe2026');
  await tester.ensureVisible(find.byKey(const Key('register_submit')));
  if (acceptTerms) await tester.tap(find.byKey(const Key('register_terms')));
}

void main() {
  testWidgets('shows validation errors on empty login', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();
    expect(find.text('L\'e-mail est obligatoire'), findsOneWidget);
    expect(find.text('Le mot de passe est obligatoire'), findsOneWidget);
  });

  testWidgets('wrong password shows an error banner', (tester) async {
    await pumpApp(tester);
    await tester.enterText(
      find.byKey(const Key('login_email')),
      MockAuthRepository.demoEmail,
    );
    await tester.enterText(find.byKey(const Key('login_password')), 'nope');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();
    expect(find.text('E-mail ou mot de passe incorrect.'), findsOneWidget);
  });

  testWidgets('demo account logs in then logs out', (tester) async {
    await pumpApp(tester);
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
    expect(find.textContaining('Bonjour Amine'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav_profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
    expect(find.text('Bon retour !'), findsOneWidget);
  });

  testWidgets('by default only the e-mail is verified before home', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('go_register')));
    await tester.pumpAndSettle();
    await fillRegisterForm(
      tester,
      firstName: 'Nour',
      lastName: 'Gharbi',
      email: 'nour@univ.tn',
      phone: '22333444',
    );
    await tester.tap(find.byKey(const Key('register_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Vérifiez votre e-mail'), findsOneWidget);

    await tester.tap(find.byKey(const Key('verify_check')));
    await tester.pumpAndSettle();
    expect(find.text('Vérifiez votre numéro'), findsNothing);
    expect(find.textContaining('Bonjour Nour Gharbi'), findsOneWidget);
  });

  testWidgets('with SMS on, sign-up needs e-mail then SMS before home', (
    tester,
  ) async {
    await pumpApp(tester, requirePhone: true);
    await tester.tap(find.byKey(const Key('go_register')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Conducteur'), findsNothing);

    await fillRegisterForm(
      tester,
      firstName: 'Salma',
      lastName: 'Trabelsi',
      email: 'salma@univ.tn',
      phone: '22333444',
      acceptTerms: false,
    );
    await tester.tap(find.byKey(const Key('register_submit')));
    await tester.pump();
    expect(
      find.text('Vous devez accepter les conditions pour continuer'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('register_terms')));
    await tester.tap(find.byKey(const Key('register_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Vérifiez votre e-mail'), findsOneWidget);
    expect(find.textContaining('salma@univ.tn'), findsOneWidget);
    expect(find.textContaining('Bonjour'), findsNothing);

    await tester.tap(find.byKey(const Key('verify_check')));
    await tester.pumpAndSettle();
    expect(find.text('Vérifiez votre numéro'), findsOneWidget);
    expect(find.text('22333444'), findsOneWidget);

    await tester.tap(find.byKey(const Key('phone_send')));
    await tester.pumpAndSettle();
    expect(find.textContaining('+216 22 333 444'), findsWidgets);

    await tester.enterText(find.byKey(const Key('phone_code')), '000000');
    await tester.tap(find.byKey(const Key('phone_confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Code incorrect.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('phone_code')),
      MockAuthRepository.demoSmsCode,
    );
    await tester.tap(find.byKey(const Key('phone_confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bonjour Salma Trabelsi'), findsOneWidget);
  });

  testWidgets('with SMS on, a number confirmed elsewhere is refused', (
    tester,
  ) async {
    await pumpApp(tester, requirePhone: true);
    await tester.tap(find.byKey(const Key('go_register')));
    await tester.pumpAndSettle();
    // Same number as the demo account, typed in another format.
    await fillRegisterForm(
      tester,
      firstName: 'Karim',
      lastName: 'Haddad',
      email: 'karim@univ.tn',
      phone: '98 111 222',
    );
    await tester.tap(find.byKey(const Key('register_submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('verify_check')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('phone_send')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('phone_code')),
      MockAuthRepository.demoSmsCode,
    );
    await tester.tap(find.byKey(const Key('phone_confirm')));
    await tester.pumpAndSettle();
    expect(
      find.text('Ce numéro est déjà associé à un autre compte SafeTrip.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('phone_change')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('phone_number')), '55000111');
    await tester.tap(find.byKey(const Key('phone_send')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('phone_code')),
      MockAuthRepository.demoSmsCode,
    );
    await tester.tap(find.byKey(const Key('phone_confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bonjour Karim Haddad'), findsOneWidget);
  });

  testWidgets('unverified account can resend the link or switch account', (
    tester,
  ) async {
    final repository = MockAuthRepository();
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(
      () => repository.register(
        const RegistrationData(
          firstName: 'Yassine',
          lastName: 'Jaziri',
          email: 'yassine@univ.tn',
          phone: '22333444',
          password: 'Safe2026',
        ),
      ),
    );
    await tester.pumpWidget(
      SafeTripApp(
        authRepository: repository,
        profileRepository: MockProfileRepository(repository),
        tripRepository: MockTripRepository(),
        demoMode: true,
        showIntro: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Vérifiez votre e-mail'), findsOneWidget);

    await tester.tap(find.byKey(const Key('verify_resend')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Nouvel e-mail envoyé.'), findsOneWidget);
    expect(find.textContaining('Renvoyer l\'e-mail ('), findsOneWidget);

    await tester.pump(const Duration(seconds: 61));
    expect(find.text('Renvoyer l\'e-mail'), findsOneWidget);

    await tester.tap(find.byKey(const Key('verify_sign_out')));
    await tester.pumpAndSettle();
    expect(find.text('Bon retour !'), findsOneWidget);
  });
}
