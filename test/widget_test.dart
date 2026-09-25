import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/features/onboarding/application/onboarding_provider.dart';
import 'package:statoo/main.dart';

void main() {
  testWidgets('App smoke test', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hasSeenOnboardingProvider.overrideWith(
            () => OnboardingNotifier(initialValue: true),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Accueil'), findsNWidgets(2));
  });
}
