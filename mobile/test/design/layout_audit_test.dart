import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/core/widgets/app_card.dart';
import 'package:statoo/features/finance/application/finance_providers.dart';
import 'package:statoo/features/finance/domain/financial_defaults.dart';
import 'package:statoo/features/finance/domain/financial_report.dart';
import 'package:statoo/features/finance/presentation/finances_screen.dart';
import 'package:statoo/features/onboarding/presentation/onboarding_screen.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/players/domain/player.dart';
import 'package:statoo/features/players/presentation/edit_player_bottom_sheet.dart';
import 'package:statoo/features/settings/presentation/financial_defaults_section.dart';
import 'package:statoo/features/team/application/team_provider.dart';

final _player = Player(
  id: 'a',
  teamId: 'g',
  name: 'Alice au nom particulièrement long',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _Members extends PlayersNotifier {
  @override
  Future<List<Player>> build() async => [_player];
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr_FR');
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [320.0, 393.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final dark in [false, true]) {
        for (final page in ['finance', 'defaults', 'onboarding', 'edit']) {
          testWidgets('$page width=$width scale=$scale dark=$dark', (
            tester,
          ) async {
            tester.view.physicalSize = Size(width, width == 320 ? 640 : 852);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final home = switch (page) {
              'finance' => const FinancesScreen(),
              'defaults' => const Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: AppCard(child: FinancialDefaultsSection()),
                ),
              ),
              'onboarding' => const OnboardingScreen(),
              _ => Scaffold(body: EditPlayerBottomSheet(player: _player)),
            };
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  activeTeamIdProvider.overrideWith(
                    () => ActiveTeamIdNotifier(initialValue: 'g'),
                  ),
                  playersListProvider.overrideWith(_Members.new),
                  financialDefaultsProvider.overrideWith(
                    (ref) async => const FinancialDefaults(
                      contribution: 1000000000000,
                      latePenalty: 1000000000000,
                    ),
                  ),
                  financialReportProvider.overrideWith(
                    (ref) async => FinancialReport(
                      asOf: DateTime(2026, 10, 15),
                      cash: 999999999999,
                      members: const {
                        'a': MemberFinancialPosition(
                          contributionsPaid: 999999999999,
                          contributionsExpected: 999999999999,
                          penaltiesExpected: 999999999999,
                        ),
                      },
                    ),
                  ),
                ],
                child: MaterialApp(
                  theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: home,
                ),
              ),
            );
            if (page == 'onboarding') {
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 500));
            } else {
              await tester.pumpAndSettle();
            }
            expect(tester.takeException(), isNull);
            if (page == 'finance') {
              final row = find.byKey(const ValueKey('member-a'));
              await tester.scrollUntilVisible(
                row,
                180,
                scrollable: find
                    .descendant(
                      of: find.byType(ListView).first,
                      matching: find.byType(Scrollable),
                    )
                    .first,
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              if (scale > 1.3) {
                for (final label in ['Payé', 'Attendu', 'Écart']) {
                  expect(
                    find.descendant(of: row, matching: find.text(label)),
                    findsOneWidget,
                  );
                }
                expect(
                  find.descendant(of: row, matching: find.textContaining(' F')),
                  findsWidgets,
                );
              }
              await tester.tap(
                find.ancestor(of: row, matching: find.byType(InkWell)).first,
              );
              await tester.pumpAndSettle();
              expect(find.text('Reste à régler'), findsOneWidget);
              expect(tester.takeException(), isNull);
            } else if (page == 'onboarding') {
              for (var i = 0; i < 2; i++) {
                await tester.ensureVisible(find.text('Suivant'));
                await tester.tap(find.text('Suivant'));
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 500));
                expect(tester.takeException(), isNull);
              }
              expect(find.text('Commencer'), findsOneWidget);
            } else if (page == 'edit') {
              tester.view.viewInsets = const FakeViewPadding(bottom: 300);
              addTearDown(tester.view.resetViewInsets);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              expect(find.text('Modifier le joueur'), findsOneWidget);
              await tester.ensureVisible(
                find.text('Enregistrer les modifications'),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
          });
        }
      }
    }
  }
}
