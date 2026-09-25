import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/onboarding/application/onboarding_provider.dart';
import 'package:statoo/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OnboardingScreen', () {
    testWidgets('renders first slide with Suivez vos matchs and Passer button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Suivez vos matchs 5v5'), findsOneWidget);
      expect(find.text('Passer'), findsOneWidget);
      expect(find.text('Suivant'), findsOneWidget);
    });

    testWidgets('swipes to slide 2 and slide 3 showing Commencer button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Suivant -> Page 2
      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
      expect(find.text('Tirage rapide & équilibré'), findsOneWidget);

      // Tap Suivant -> Page 3
      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
      expect(find.text('Classement & Statistiques'), findsOneWidget);
      expect(find.text('Commencer'), findsOneWidget);
      expect(find.text('Passer'), findsNothing);
    });

    test('OnboardingNotifier sets hasSeenOnboarding to true in SharedPreferences', () async {
      final container = ProviderContainer();
      final notifier = container.read(hasSeenOnboardingProvider.notifier);

      await notifier.completeOnboarding();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('hasSeenOnboarding'), isTrue);
      expect(container.read(hasSeenOnboardingProvider), isTrue);
    });
  });
}
