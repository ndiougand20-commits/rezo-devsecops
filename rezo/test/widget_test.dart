import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rezo/features/auth/auth_flow.dart';
import 'package:rezo/main.dart';

class _FakeAuthServiceWithRecommendations extends FakeAuthService {
  @override
  Future<Map<String, dynamic>> fetchRecommendations({
    bool includeSwiped = false,
  }) async {
    return <String, dynamic>{
      'recommendations': <Map<String, dynamic>>[
        <String, dynamic>{
          'offerId': 'offer-1',
          'score': 92,
          'reasons': <String>['Stack Flutter alignée'],
          'offer': <String, dynamic>{
            'id': 'offer-1',
            'titre': 'Stage Flutter',
            'ownerDisplayName': 'Rezo Labs',
            'location': 'Dakar',
            'type': 'STAGE',
            'domaine': 'Informatique',
            'competencesRequises': <String>['Flutter', 'Dart'],
            'description': 'Mission mobile Flutter',
          },
        },
      ],
      'suggestedPack': null,
      'trace': <String, dynamic>{
        'hasOpportunityAccess': true,
        'availableOfferCount': 1,
      },
    };
  }
}

Future<void> _openLoginScreen(WidgetTester tester) async {
  final loginCta = find.widgetWithText(ElevatedButton, 'Se connecter');
  if (loginCta.evaluate().isEmpty) {
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    navigator.pushNamedAndRemoveUntil(
      AppRoutes.welcome,
      (route) => false,
      arguments: UserRole.etudiant,
    );
    await tester.pumpAndSettle();
  }
  expect(loginCta, findsOneWidget);
  await tester.ensureVisible(loginCta);
  await tester.tap(loginCta);
  await tester.pumpAndSettle();
}

Future<void> _loginDefaultUser(WidgetTester tester) async {
  await _openLoginScreen(tester);
  expect(find.byType(LoginScreen), findsOneWidget);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Adresse e-mail'),
    'awa@rezo.sn',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Mot de passe'),
    'SecurePass123!',
  );
  final submitCta = find.widgetWithText(ElevatedButton, 'Connexion');
  await tester.scrollUntilVisible(
    submitCta,
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(submitCta, warnIfMissed: false);
  await tester.pumpAndSettle();
  if (find.byType(LoginScreen).evaluate().isNotEmpty) {
    await tester.tap(submitCta, warnIfMissed: false);
    await tester.pumpAndSettle();
  }
}

void main() {
  group('Auth tunnel UX', () {
    testWidgets('role choice screen appears before welcome auth screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MyApp(
          authService: FakeAuthService(),
          tokenStorage: MemoryTokenStorage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RoleChoiceScreen), findsOneWidget);
      expect(find.text('Choisis ton profil'), findsOneWidget);

      final context = tester.element(find.byType(RoleChoiceScreen));
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.welcome,
        arguments: UserRole.etudiant,
      );
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Le bon contact, au bon moment.'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.text('Créer un compte'), findsOneWidget);
    });

    testWidgets('signup validation shows feedback for invalid fields', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignupScreen(initialRole: UserRole.etudiant),
        ),
      );
      await tester.pumpAndSettle();

      final formState = tester.state<FormState>(find.byType(Form).first);
      expect(formState.validate(), isFalse);
      await tester.pump();

      expect(find.text('Veuillez renseigner un email valide'), findsOneWidget);
      expect(find.text('8 caractères minimum'), findsOneWidget);
    });

    testWidgets('login success stores token and redirects to dashboard', (
      WidgetTester tester,
    ) async {
      final storage = MemoryTokenStorage();

      await tester.pumpWidget(
        MyApp(authService: FakeAuthService(), tokenStorage: storage),
      );
      await tester.pumpAndSettle();

      await _loginDefaultUser(tester);

      expect(await storage.readToken(), equals('fake-jwt-token'));
      expect(find.text('Matching'), findsWidgets);
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('session persisted opens dashboard on app launch', (
      WidgetTester tester,
    ) async {
      final storage = MemoryTokenStorage();
      await storage.saveToken('persisted-jwt');

      await tester.pumpWidget(
        MyApp(authService: FakeAuthService(), tokenStorage: storage),
      );
      await tester.pumpAndSettle();

      expect(find.text('Matching'), findsWidgets);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('dashboard route is protected when user is not authenticated', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MyApp(
          authService: FakeAuthService(),
          tokenStorage: MemoryTokenStorage(),
        ),
      );
      await tester.pumpAndSettle();

      final roleChoiceContext = tester.element(find.byType(RoleChoiceScreen));
      Navigator.of(roleChoiceContext).pushReplacementNamed(
        AppRoutes.welcome,
        arguments: UserRole.etudiant,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(WelcomeScreen));
      Navigator.of(context).pushNamed(AppRoutes.dashboard);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Connexion'), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
    });

    testWidgets('profile edit updates visible data immediately', (
      WidgetTester tester,
    ) async {
      final storage = MemoryTokenStorage();

      await tester.pumpWidget(
        MyApp(authService: FakeAuthService(), tokenStorage: storage),
      );
      await tester.pumpAndSettle();

      await _loginDefaultUser(tester);

      await tester.tap(find.byTooltip('Mon profil'), warnIfMissed: false);
      await tester.pumpAndSettle();

      final dashboardContext = tester.element(find.byType(DashboardScreen));
      final appState = AppScope.of(dashboardContext);
      await appState.updateProfile({'prenom': 'Nina'});
      await tester.pumpAndSettle();

      expect(appState.currentUser?['prenom'], equals('Nina'));
    });

    testWidgets('changing pack updates current pack badge', (
      WidgetTester tester,
    ) async {
      final storage = MemoryTokenStorage();

      await tester.pumpWidget(
        MyApp(authService: FakeAuthService(), tokenStorage: storage),
      );
      await tester.pumpAndSettle();

      await _loginDefaultUser(tester);

      await tester.tap(find.byTooltip('Mon profil'), warnIfMissed: false);
      await tester.pumpAndSettle();

      final dashboardContext = tester.element(find.byType(DashboardScreen));
      final appState = AppScope.of(dashboardContext);
      await appState.changePack('pack-pro');
      await tester.pumpAndSettle();

      expect(appState.currentUser?['packNom'], equals('PRO'));
    });

    testWidgets('profile edit blocks invalid phone format', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MyApp(
          authService: FakeAuthService(),
          tokenStorage: MemoryTokenStorage(),
        ),
      );
      await tester.pumpAndSettle();

      await _loginDefaultUser(tester);

      await tester.tap(find.byTooltip('Mon profil'), warnIfMissed: false);
      await tester.pumpAndSettle();

      final editCta = find.widgetWithText(ElevatedButton, 'Modifier le profil');
      await tester.ensureVisible(editCta);
      await tester.tap(editCta, warnIfMissed: false);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Téléphone'),
        '12',
      );
      final formState = tester.state<FormState>(find.byType(Form));
      expect(formState.validate(), isFalse);
      await tester.pump();

      expect(find.text('Numéro de téléphone invalide'), findsOneWidget);
    }, skip: true);

    testWidgets('matching tab shows suggestions and reacts to swipe actions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MyApp(
          authService: _FakeAuthServiceWithRecommendations(),
          tokenStorage: MemoryTokenStorage(),
        ),
      );
      await tester.pumpAndSettle();

      await _loginDefaultUser(tester);

      final introCta = find.widgetWithText(FilledButton, "J'ai compris");
      if (introCta.evaluate().isNotEmpty) {
        await tester.tap(introCta, warnIfMissed: false);
        await tester.pumpAndSettle();
      }

      // New swipe-based design: score badge + circular action buttons
      expect(find.textContaining('% compatible'), findsWidgets);

      // Swipe right on the card to like the current suggestion
      await tester.drag(find.text('Stage Flutter'), const Offset(180, 0));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ajout\u00e9 \u00e0 tes favoris'), findsOneWidget);
    });
  });
}
