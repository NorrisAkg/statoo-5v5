import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/shared/presentation/widgets/password_complexity_indicator.dart';

void main() {
  Widget buildHarness({
    required String password,
    String? username,
    ThemeData? theme,
  }) {
    return MaterialApp(
      theme: theme ?? AppTheme.darkTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: PasswordComplexityIndicator(
              password: password,
              username: username,
            ),
          ),
        ),
      ),
    );
  }

  bool isCriterionMet(WidgetTester tester, Pattern labelPattern) {
    final Finder textFinder = find.textContaining(labelPattern);
    expect(
      textFinder,
      findsOneWidget,
      reason: 'Le critère "$labelPattern" doit être affiché dans le widget.',
    );
    final Finder rowFinder =
        find.ancestor(of: textFinder, matching: find.byType(Row)).first;
    final Finder checkFinder = find.descendant(
      of: rowFinder,
      matching: find.byIcon(Remix.check_line),
    );
    return checkFinder.evaluate().isNotEmpty;
  }

  group('PasswordComplexityIndicator Widget Tests', () {
    group('Critère 1 : Longueur minimale (au moins 8 caractères)', () {
      testWidgets(
        'G-W-T 1.1: Mot de passe vide -> Le critère longueur est NON validé',
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildHarness(password: '', username: 'alex'),
          );
          await tester.pumpAndSettle();

          // Then
          expect(isCriterionMet(tester, '8 caractères'), isFalse);
        },
      );

      testWidgets(
        'G-W-T 1.2: Mot de passe de 7 caractères ("Abcde1!") -> Le critère longueur est NON validé',
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildHarness(password: 'Abcde1!', username: 'alex'),
          );
          await tester.pumpAndSettle();

          // Then
          expect(isCriterionMet(tester, '8 caractères'), isFalse);
        },
      );

      testWidgets(
        'G-W-T 1.3: Mot de passe de 8 caractères exacts ("Abcdef1!") -> Le critère longueur est VALIDÉ',
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildHarness(password: 'Abcdef1!', username: 'alex'),
          );
          await tester.pumpAndSettle();

          // Then
          expect(isCriterionMet(tester, '8 caractères'), isTrue);
        },
      );

      testWidgets(
        'G-W-T 1.4: Mot de passe supérieur à 8 caractères ("UnTresLongPass123!") -> Le critère longueur est VALIDÉ',
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildHarness(password: 'UnTresLongPass123!', username: 'alex'),
          );
          await tester.pumpAndSettle();

          // Then
          expect(isCriterionMet(tester, '8 caractères'), isTrue);
        },
      );
    });

    group('Critère 2 : Au moins une majuscule (A-Z)', () {
      testWidgets(
        'G-W-T 2.1: Mot de passe sans majuscule ("abcdef123!") -> Le critère majuscule est NON validé',
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildHarness(password: 'abcdef123!', username: 'alex'),
          );
          await tester.pumpAndSettle();

          // Then
          expect(isCriterionMet(tester, 'majuscule'), isFalse);
        },
      );

      testWidgets(
        'G-W-T 2.2: Mot de passe avec au moins une majuscule ("Abcdef123!") -> Le critère majuscule est VALIDÉ',
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildHarness(password: 'Abcdef123!', username: 'alex'),
          );
          await tester.pumpAndSettle();

          // Then
          expect(isCriterionMet(tester, 'majuscule'), isTrue);
        },
      );

      testWidgets(
        'G-W-T 2.3: Mot de passe tout en majuscules ("ABCDEF123!") -> Le critère majuscule est VALIDÉ',
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildHarness(password: 'ABCDEF123!', username: 'alex'),
          );
          await tester.pumpAndSettle();

          // Then
          expect(isCriterionMet(tester, 'majuscule'), isTrue);
        },
      );
    });

    group('Critère 3 : Au moins une minuscule (a-z)', () {
      testWidgets(
        'G-W-T 3.1: Mot de passe sans minuscule ("ABCDEF123!") -> Le critère minuscule est NON validé',
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildHarness(password: 'ABCDEF123!', username: 'alex'),
          );
          await tester.pumpAndSettle();

          // Then
          expect(isCriterionMet(tester, 'minuscule'), isFalse);
        },
      );

      testWidgets(
        'G-W-T 3.2: Mot de passe avec au moins une minuscule ("Abcdef123!") -> Le critère minuscule est VALIDÉ',
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildHarness(password: 'Abcdef123!', username: 'alex'),
          );
          await tester.pumpAndSettle();

          // Then
          expect(isCriterionMet(tester, 'minuscule'), isTrue);
        },
      );
    });

    group('Critère 4 : Au moins un chiffre (0-9)', () {
      testWidgets(
        'G-W-T 4.1: Mot de passe sans aucun chiffre ("Abcdefghij!") -> Le critère chiffre est NON validé',
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildHarness(password: 'Abcdefghij!', username: 'alex'),
          );
          await tester.pumpAndSettle();

          // Then
          expect(isCriterionMet(tester, 'chiffre'), isFalse);
        },
      );

      testWidgets(
        'G-W-T 4.2: Mot de passe avec au moins un chiffre ("Abcdefghi1!") -> Le critère chiffre est VALIDÉ',
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildHarness(password: 'Abcdefghi1!', username: 'alex'),
          );
          await tester.pumpAndSettle();

          // Then
          expect(isCriterionMet(tester, 'chiffre'), isTrue);
        },
      );
    });

    group("Critère 5 : Différent du nom d'utilisateur (si fourni)", () {
      testWidgets(
        "G-W-T 5.1: Username absent (null) -> Le critère nom d'utilisateur n'est pas requis ou est masqué",
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildHarness(password: 'Abcdef123!'),
          );
          await tester.pumpAndSettle();

          // Then
          final Finder userCriterion =
              find.textContaining("nom d'utilisateur");
          expect(userCriterion, findsNothing);
        },
      );

      testWidgets(
        'G-W-T 5.2: Username vide ("") -> Le critère nom d\'utilisateur n\'est pas affiché',
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildHarness(password: 'Abcdef123!', username: '   '),
          );
          await tester.pumpAndSettle();

          // Then
          final Finder userCriterion =
              find.textContaining("nom d'utilisateur");
          expect(userCriterion, findsNothing);
        },
      );

      testWidgets(
        'G-W-T 5.3: Username fourni ("alex") et mot de passe identique ("alex") -> Le critère est NON validé',
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildHarness(password: 'alex', username: 'alex'),
          );
          await tester.pumpAndSettle();

          // Then
          expect(isCriterionMet(tester, "nom d'utilisateur"), isFalse);
        },
      );

      testWidgets(
        'G-W-T 5.4: Username fourni ("alex") et mot de passe identique insensible à la casse ("ALEX") -> NON validé',
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildHarness(password: 'ALEX', username: 'alex'),
          );
          await tester.pumpAndSettle();

          // Then
          expect(isCriterionMet(tester, "nom d'utilisateur"), isFalse);
        },
      );

      testWidgets(
        'G-W-T 5.5: Username fourni ("alex") et mot de passe identique avec espaces (" alex ") -> NON validé',
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildHarness(password: ' alex ', username: 'alex'),
          );
          await tester.pumpAndSettle();

          // Then
          expect(isCriterionMet(tester, "nom d'utilisateur"), isFalse);
        },
      );

      testWidgets(
        'G-W-T 5.6: Username fourni ("alex") et mot de passe différent ("Secur3Pass!") -> Le critère est VALIDÉ',
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildHarness(password: 'Secur3Pass!', username: 'alex'),
          );
          await tester.pumpAndSettle();

          // Then
          expect(isCriterionMet(tester, "nom d'utilisateur"), isTrue);
        },
      );
    });

    group('Tous les critères validés simultanément', () {
      testWidgets(
        'G-W-T 6.1: Mot de passe complet et conforme ("Secur3Pass!") -> Tous les critères sont cochés',
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildHarness(password: 'Secur3Pass!', username: 'alex'),
          );
          await tester.pumpAndSettle();

          // Then
          expect(isCriterionMet(tester, '8 caractères'), isTrue);
          expect(isCriterionMet(tester, 'majuscule'), isTrue);
          expect(isCriterionMet(tester, 'minuscule'), isTrue);
          expect(isCriterionMet(tester, 'chiffre'), isTrue);
          expect(isCriterionMet(tester, "nom d'utilisateur"), isTrue);
          expect(find.byIcon(Remix.check_line), findsNWidgets(5));
          expect(find.byIcon(Remix.close_line), findsNothing);
        },
      );
    });

    group('Réactivité dynamique lors de la saisie progressive', () {
      testWidgets(
        'G-W-T 7.1: Met à jour dynamiquement chaque critère lors de la frappe dans un TextField',
        (tester) async {
          // Given
          String currentPassword = '';
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    return Column(
                      children: <Widget>[
                        TextField(
                          key: const Key('password_input'),
                          onChanged: (value) {
                            setState(() {
                              currentPassword = value;
                            });
                          },
                        ),
                        PasswordComplexityIndicator(
                          password: currentPassword,
                          username: 'alex',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // État initial vide
          expect(isCriterionMet(tester, '8 caractères'), isFalse);
          expect(isCriterionMet(tester, 'majuscule'), isFalse);
          expect(isCriterionMet(tester, 'minuscule'), isFalse);
          expect(isCriterionMet(tester, 'chiffre'), isFalse);

          // Étape 1 : minuscule seule ("a")
          await tester.enterText(find.byKey(const Key('password_input')), 'a');
          await tester.pumpAndSettle();
          expect(isCriterionMet(tester, 'minuscule'), isTrue);
          expect(isCriterionMet(tester, 'majuscule'), isFalse);

          // Étape 2 : ajout majuscule ("aB")
          await tester.enterText(find.byKey(const Key('password_input')), 'aB');
          await tester.pumpAndSettle();
          expect(isCriterionMet(tester, 'minuscule'), isTrue);
          expect(isCriterionMet(tester, 'majuscule'), isTrue);
          expect(isCriterionMet(tester, 'chiffre'), isFalse);

          // Étape 3 : ajout chiffre ("aB1")
          await tester.enterText(find.byKey(const Key('password_input')), 'aB1');
          await tester.pumpAndSettle();
          expect(isCriterionMet(tester, 'chiffre'), isTrue);
          expect(isCriterionMet(tester, '8 caractères'), isFalse);

          // Étape 4 : atteinte de 8 caractères ("aB1cdefg")
          await tester.enterText(
            find.byKey(const Key('password_input')),
            'aB1cdefg',
          );
          await tester.pumpAndSettle();
          expect(isCriterionMet(tester, '8 caractères'), isTrue);
          expect(isCriterionMet(tester, "nom d'utilisateur"), isTrue);
        },
      );
    });

    group('Support du thème (Clair et Sombre)', () {
      testWidgets(
        'G-W-T 8.1: Se rend sans erreur dans le thème sombre (AppTheme.darkTheme)',
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildHarness(
              password: 'Pass1234',
              username: 'alex',
              theme: AppTheme.darkTheme,
            ),
          );
          await tester.pumpAndSettle();

          // Then
          expect(find.byType(PasswordComplexityIndicator), findsOneWidget);
        },
      );

      testWidgets(
        'G-W-T 8.2: Se rend sans erreur dans le thème clair (AppTheme.lightTheme)',
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildHarness(
              password: 'Pass1234',
              username: 'alex',
              theme: AppTheme.lightTheme,
            ),
          );
          await tester.pumpAndSettle();

          // Then
          expect(find.byType(PasswordComplexityIndicator), findsOneWidget);
        },
      );
    });
  });
}
