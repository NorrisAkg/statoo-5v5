import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:statoo/core/theme/app_colors.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/core/widgets/primary_button.dart';
import 'package:statoo/features/team/application/team_provider.dart';
import 'package:statoo/features/team/presentation/create_team_screen.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x < y ? x : y) + .05);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  test(
    'UX08-13 contrast oracle is symmetric, 21 for black/white, 1 for same',
    () {
      expect(contrast(Colors.black, Colors.white), 21);
      expect(contrast(Colors.white, Colors.black), 21);
      expect(contrast(Colors.green, Colors.green), 1);
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'UX08-01/02 actual primary button has normal text contrast dark=$dark',
      (tester) async {
        final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: PrimaryButton(label: 'Enregistrer', onPressed: () {}),
            ),
          ),
        );
        final button = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        final bg = button.style!.backgroundColor!.resolve({})!;
        final fg = button.style!.foregroundColor!.resolve({})!;
        expect(contrast(bg, fg), greaterThanOrEqualTo(4.5));
        expect(
          contrast(theme.colorScheme.primary, theme.colorScheme.onPrimary),
          greaterThanOrEqualTo(4.5),
        );
      },
    );
    test('UX08-06/07 green text contrasts with page and card dark=$dark', () {
      final colors = dark ? AppColors.dark : AppColors.light;
      for (final bg in [
        colors.background950,
        colors.background900,
        colors.background800,
      ]) {
        expect(contrast(colors.primary400, bg), greaterThanOrEqualTo(4.5));
      }
    });
    testWidgets(
      'UX08-08 actual back icon contrasts with transparent app bar dark=$dark',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hasTeamProvider.overrideWith(
                () => HasTeamNotifier(initialValue: true),
              ),
            ],
            child: MaterialApp(
              theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const CreateTeamScreen(),
                      ),
                    ),
                    child: const Text('Ouvrir'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Ouvrir'));
        await tester.pumpAndSettle();
        final bar = find.byType(AppBar);
        final icon = find
            .descendant(of: bar, matching: find.byType(Icon))
            .first;
        final effectiveColor = IconTheme.of(tester.element(icon)).color!;
        final scaffold = tester.widget<Scaffold>(
          find.ancestor(of: bar, matching: find.byType(Scaffold)).first,
        );
        expect(
          contrast(effectiveColor, scaffold.backgroundColor!),
          greaterThanOrEqualTo(3),
        );
      },
    );
  }
}
