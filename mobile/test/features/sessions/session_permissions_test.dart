import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/domain/participation.dart';
import 'package:statoo/features/sessions/presentation/session_detail_screen.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/shared/data/shared_service.dart';
import 'package:statoo/features/team/application/team_provider.dart';

class _DeniedController extends SessionsController {
  _DeniedController(super.ref);
  @override
  Future<void> recordLive(
    String id,
    Map<String, dynamic>? action, {
    String? edit,
  }) async {
    throw StateError('Le rôle SG a été retiré.');
  }
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr_FR');
  });
  testWidgets(
    'UX06-02 readonly active session stays labelled in progress without mutations',
    (tester) async {
      final service = SharedService(AppDatabase.instance)
        ..protectedGroups.add('g')
        ..identity = {
          'group_id': 'g',
          'expires_at': '2099-01-01T00:00:00Z',
          'account': {
            'id': 'me',
            'roles': ['MEMBER'],
          },
        };
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTeamIdProvider.overrideWith(
              () => ActiveTeamIdNotifier(initialValue: 'g'),
            ),
            sharedServiceProvider.overrideWithValue(service),
            sessionDetailProvider('s').overrideWith(
              (ref) async => Session(
                id: 's',
                playedAt: DateTime(2026, 10, 14),
                scoreA: 0,
                scoreB: 0,
                result: MatchResult.draw,
              ),
            ),
            sessionParticipantsProvider('s').overrideWith((ref) async => []),
            activeSessionIdProvider.overrideWith((ref) async => 's'),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SessionDetailScreen(sessionId: 's'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('En cours'), findsOneWidget);
      expect(find.byTooltip('Clôturer la séance'), findsNothing);
      expect(find.text('Ajouter un joueur'), findsNothing);
      expect(find.text('Ajouter des joueurs (retardataires)'), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('UX06-08 late score denial is reported without unhandled error', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeTeamIdProvider.overrideWith(
            () => ActiveTeamIdNotifier(initialValue: 'g'),
          ),
          sessionDetailProvider('s').overrideWith(
            (ref) async => Session(
              id: 's',
              playedAt: DateTime(2026, 10, 14),
              scoreA: 0,
              scoreB: 0,
              result: MatchResult.draw,
            ),
          ),
          sessionParticipantsProvider('s').overrideWith((ref) async => []),
          activeSessionIdProvider.overrideWith((ref) async => 's'),
          canWriteSessionProvider((domain: 'sport', sessionId: 's'))
              .overrideWith((ref) async => true),
          sessionsControllerProvider.overrideWith(_DeniedController.new),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SessionDetailScreen(sessionId: 's'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final goal = find.text('Ajouter un but');
    await tester.scrollUntilVisible(
      goal,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(goal);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buteur non renseigné'));
    await tester.pumpAndSettle();
    expect(find.textContaining('SG a été retiré'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
