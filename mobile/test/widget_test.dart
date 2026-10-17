import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/features/onboarding/application/onboarding_provider.dart';
import 'package:statoo/features/team/application/team_provider.dart';
import 'package:statoo/main.dart';

void main() {
  testWidgets('Shows group entry after onboarding when no team exists', (tester) async {
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

    expect(find.text('Créer un groupe'), findsOneWidget);
    expect(find.text('Rejoindre un groupe'), findsOneWidget);
  });

  testWidgets('App smoke test when onboarding and team exist', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeTeamIdProvider.overrideWith(() => ActiveTeamIdNotifier(initialValue: 'team_1')),
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

    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Nouvelle séance'), findsOneWidget);
  });
}
