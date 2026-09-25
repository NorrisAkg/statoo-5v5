import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/features/onboarding/application/onboarding_provider.dart';
import 'package:statoo/features/team/application/team_provider.dart';
import 'package:statoo/main.dart';

void main() {
  testWidgets('Redirects to /creer-equipe after onboarding when no team exists', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hasSeenOnboardingProvider.overrideWith(
            () => OnboardingNotifier(initialValue: true),
          ),
          hasTeamProvider.overrideWith(
            () => HasTeamNotifier(initialValue: false),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Créez votre équipe'), findsOneWidget);
  });

  testWidgets('App smoke test when onboarding and team exist', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hasSeenOnboardingProvider.overrideWith(
            () => OnboardingNotifier(initialValue: true),
          ),
          hasTeamProvider.overrideWith(
            () => HasTeamNotifier(initialValue: true),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Accueil'), findsNWidgets(2));
  });
}

