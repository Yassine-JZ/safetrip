import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip/app.dart';
import 'package:safetrip/features/auth/data/auth_repository.dart';
import 'package:safetrip/features/auth/data/mock_auth_repository.dart';

Future<void> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SafeTripApp(
      authRepository: MockAuthRepository(),
      demoMode: true,
      showIntro: false,
    ),
  );
  await tester.pumpAndSettle();
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

    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
    expect(find.text('Bon retour !'), findsOneWidget);
  });

  testWidgets('registration requires e-mail verification before home', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('go_register')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Conducteur'), findsNothing);

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
    await tester.enterText(find.byKey(const Key('register_phone')), '22333444');
    await tester.enterText(
      find.byKey(const Key('register_password')),
      'Safe2026',
    );
    await tester.enterText(
      find.byKey(const Key('register_confirm')),
      'Safe2026',
    );

    await tester.ensureVisible(find.byKey(const Key('register_submit')));
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
    expect(find.textContaining('Bonjour Salma Trabelsi'), findsOneWidget);
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
      SafeTripApp(authRepository: repository, demoMode: true, showIntro: false),
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
