import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/data/sessions_repository.dart';
import 'package:statoo/features/sessions/domain/participation.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/domain/session_summary.dart';
import 'package:statoo/features/sessions/presentation/session_detail_screen.dart';
import 'package:statoo/features/team/application/team_provider.dart';

class _FakeSessionDetailRepository implements SessionsRepository {
  _FakeSessionDetailRepository({
    required this.session,
    required this.participants,
  });

  final Session session;
  final List<SessionParticipantDetail> participants;

  @override
  Future<Session?> getSession(String id, {required String teamId}) async => session;

  @override
  Future<List<SessionParticipantDetail>> getSessionParticipants(String sessionId, {required String teamId}) async => participants;

  @override
  Future<String?> getActiveSessionId({required String teamId}) async => session.id;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  final playedAt = DateTime(2026, 9, 26, 20, 30);
  final testSession = Session(
    id: 's_test',
    playedAt: playedAt,
    isRanked: true,
    scoreA: 3,
    scoreB: 2,
    result: MatchResult.teamA,
  );

  final testParticipants = [
    const SessionParticipantDetail(
      participation: Participation(id: 'pt_1', sessionId: 's_test', playerId: 'p1', team: Team.a),
      playerName: 'Joueur A1',
    ),
    const SessionParticipantDetail(
      participation: Participation(id: 'pt_2', sessionId: 's_test', playerId: 'p2', team: Team.a),
      playerName: 'Joueur A2',
    ),
    const SessionParticipantDetail(
      participation: Participation(id: 'pt_3', sessionId: 's_test', playerId: 'p3', team: Team.b),
      playerName: 'Joueur B1',
    ),
    const SessionParticipantDetail(
      participation: Participation(id: 'pt_4', sessionId: 's_test', playerId: 'p4', team: Team.b),
      playerName: 'Joueur B2',
    ),
  ];

  Widget createWidget(SessionsRepository repo) {
    return ProviderScope(
      overrides: [
        sessionsRepositoryProvider.overrideWithValue(repo),
        activeSessionIdProvider.overrideWith((ref) async => 's_test'),
        activeTeamIdProvider.overrideWith(() => ActiveTeamIdNotifier(initialValue: 'team_test')),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('fr', 'FR')],
        home: const SessionDetailScreen(sessionId: 's_test'),
      ),
    );
  }

  testWidgets('SessionDetailScreen displays 2 team tabs and switches between Team A and Team B', (tester) async {
    final repo = _FakeSessionDetailRepository(session: testSession, participants: testParticipants);

    await tester.pumpWidget(createWidget(repo));
    await tester.pumpAndSettle();

    // Verify both tabs exist
    expect(find.text('Équipe A'), findsWidgets);
    expect(find.text('Équipe B'), findsWidgets);

    // By default, Team A is active: Joueur A1 and Joueur A2 are visible, Joueur B1 is not
    expect(find.text('Joueur A1'), findsOneWidget);
    expect(find.text('Joueur A2'), findsOneWidget);
    expect(find.text('Joueur B1'), findsNothing);
    expect(find.text('Joueur B2'), findsNothing);

    // Tap on the "Équipe B" tab button
    final teamBTab = find.ancestor(
      of: find.text('Équipe B'),
      matching: find.byType(GestureDetector),
    ).first;
    await tester.tap(teamBTab);
    await tester.pumpAndSettle();

    // Now Team B is active: Joueur B1 and Joueur B2 are visible, Joueur A1 is not
    expect(find.text('Joueur B1'), findsOneWidget);
    expect(find.text('Joueur B2'), findsOneWidget);
    expect(find.text('Joueur A1'), findsNothing);
    expect(find.text('Joueur A2'), findsNothing);
  });
}
