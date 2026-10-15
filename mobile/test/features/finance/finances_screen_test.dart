import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/finance/application/finance_providers.dart';
import 'package:statoo/features/finance/domain/financial_report.dart';
import 'package:statoo/features/finance/presentation/finances_screen.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/players/domain/player.dart';

class FakePlayers extends PlayersNotifier {
  @override
  Future<List<Player>> build() async => [
    for (final name in ['Zoé', 'Émile', 'Alice'])
      Player(
        id: name,
        teamId: 'g',
        name: name,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
  ];
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr_FR');
  });
  for (final dark in [false, true]) {
    testWidgets(
      'narrow table sorts, searches and exposes separate balances ($dark)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              playersListProvider.overrideWith(FakePlayers.new),
              financialReportProvider.overrideWith(
                (ref) async => FinancialReport(
                  asOf: DateTime(2026, 10, 14),
                  cash: 500,
                  members: const {
                    'Alice': MemberFinancialPosition(
                      contributionsPaid: 400,
                      contributionsExpected: 100,
                      penaltiesExpected: 100,
                    ),
                  },
                ),
              ),
            ],
            child: MaterialApp(
              theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
              home: const FinancesScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('member-Alice'))).dy,
          lessThan(
            tester.getTopLeft(find.byKey(const ValueKey('member-Émile'))).dy,
          ),
        );
        expect(find.text('Pénalités impayées : 100 F'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Alice'));
        await tester.pumpAndSettle();
        expect(find.text('Reste à régler'), findsOneWidget);
        expect(find.text('Cotisations attendues'), findsOneWidget);
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(find.text('Reste à régler'))).pop();
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'emile');
        await tester.pumpAndSettle();
        expect(find.text('Émile'), findsOneWidget);
        expect(find.text('Alice'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
