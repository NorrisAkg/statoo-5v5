import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:remixicon/remixicon.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/data/sessions_repository.dart';
import 'package:statoo/features/sessions/domain/participation.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/domain/session_summary.dart';
import 'package:statoo/features/sessions/presentation/session_detail_screen.dart';
import 'package:statoo/features/team/application/team_provider.dart';
import 'package:statoo/features/team/data/team_repository.dart';
import 'package:statoo/features/team/domain/team_info.dart';

class _FakeTeamRepository implements TeamRepository {
  _FakeTeamRepository(this._activeTeam);
  final TeamInfo? _activeTeam;

  @override
  Future<TeamInfo?> getActiveTeam() async => _activeTeam;

  @override
  Future<String?> getActiveTeamId() async => _activeTeam?.id;

  @override
  Future<TeamInfo?> getTeamById(String id) async => _activeTeam?.id == id ? _activeTeam : null;

  @override
  Future<TeamInfo?> getTeamInfo() async => _activeTeam;

  @override
  Future<List<TeamInfo>> getAllTeams() async => _activeTeam != null ? [_activeTeam] : [];

  @override
  Future<void> setActiveTeamId(String id) async {}

  @override
  Future<void> saveTeamInfo(TeamInfo team) async {}

  @override
  Future<void> deleteTeam(String id) async {}

  @override
  Future<Map<String, int>> getTeamCounts(String teamId) async => {'players': 0, 'sessions': 0};
}

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
    status: SessionStatus.closed,
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

  testWidgets('SessionDetailScreen team tabs display real custom team names and pill shape matching design', (tester) async {
    const colorA = Color(0xFF3B82F6);
    const colorB = Color(0xFFF97316);

    final customSession = testSession.copyWith(
      teamNames: const {'A': 'Les Aigles', 'B': 'Les Tigres'},
      teamColors: const {'A': 0xFF3B82F6, 'B': 0xFFF97316},
    );
    final repo = _FakeSessionDetailRepository(session: customSession, participants: testParticipants);

    await tester.pumpWidget(createWidget(repo));
    await tester.pumpAndSettle();

    // Verify real team names are displayed instead of default "Équipe A" / "Équipe B"
    expect(find.text('Les Aigles'), findsWidgets);
    expect(find.text('Les Tigres'), findsWidgets);

    // Verify tab buttons have full capsule pill borderRadius (circular(9999))
    final tabAContainer = tester.widget<AnimatedContainer>(
      find.widgetWithText(AnimatedContainer, 'Les Aigles'),
    );
    final tabADeco = tabAContainer.decoration! as BoxDecoration;
    expect(tabADeco.borderRadius, BorderRadius.circular(9999));
    expect(tabADeco.border?.top.color, colorA);

    final tabBContainer = tester.widget<AnimatedContainer>(
      find.widgetWithText(AnimatedContainer, 'Les Tigres'),
    );
    final tabBDeco = tabBContainer.decoration! as BoxDecoration;
    expect(tabBDeco.borderRadius, BorderRadius.circular(9999));
    // Unselected tab border should be transparent
    expect(tabBDeco.border?.top.color, Colors.transparent);

    // Verify selected tab counter has team color text
    final counterAText = tester.widget<Text>(find.descendant(
      of: find.widgetWithText(AnimatedContainer, 'Les Aigles'),
      matching: find.text('2'),
    ));
    expect(counterAText.style?.color, colorA);

    // Tap on the "Les Tigres" tab
    await tester.tap(find.widgetWithText(AnimatedContainer, 'Les Tigres'));
    await tester.pumpAndSettle();

    // Now Team B is selected: its border is colorB, Team A border is transparent
    final tabBAfter = tester.widget<AnimatedContainer>(
      find.widgetWithText(AnimatedContainer, 'Les Tigres'),
    );
    final tabBDecoAfter = tabBAfter.decoration! as BoxDecoration;
    expect(tabBDecoAfter.border?.top.color, colorB);

    final tabAAfter = tester.widget<AnimatedContainer>(
      find.widgetWithText(AnimatedContainer, 'Les Aigles'),
    );
    final tabADecoAfter = tabAAfter.decoration! as BoxDecoration;
    expect(tabADecoAfter.border?.top.color, Colors.transparent);

    // And counter for Team B now has colorB
    final counterBText = tester.widget<Text>(find.descendant(
      of: find.widgetWithText(AnimatedContainer, 'Les Tigres'),
      matching: find.text('2'),
    ));
    expect(counterBText.style?.color, colorB);
  });

  testWidgets('SessionDetailScreen tournament displays 3 pill tabs with custom names and capsule shape', (tester) async {
    final tournamentSession = testSession.copyWith(
      sessionType: SessionType.tournament3,
      teamNames: const {'A': 'Les Bleus', 'B': 'Les Oranges', 'C': 'Les Verts'},
      teamColors: const {'A': 0xFF3B82F6, 'B': 0xFFF97316, 'C': 0xFF22C55E},
    );
    final repo = _FakeSessionDetailRepository(session: tournamentSession, participants: testParticipants);

    await tester.pumpWidget(createWidget(repo));
    await tester.pumpAndSettle();

    expect(find.text('Les Bleus'), findsWidgets);
    expect(find.text('Les Oranges'), findsWidgets);
    expect(find.text('Les Verts'), findsWidgets);

    for (final name in ['Les Bleus', 'Les Oranges', 'Les Verts']) {
      final container = tester.widget<AnimatedContainer>(
        find.widgetWithText(AnimatedContainer, name),
      );
      final deco = container.decoration! as BoxDecoration;
      expect(deco.borderRadius, BorderRadius.circular(9999));
    }
  });

  testWidgets('SessionDetailScreen resolves active team and displays session when activeTeamIdProvider starts uninitialized (page refresh scenario)', (tester) async {
    final repo = _FakeSessionDetailRepository(session: testSession, participants: testParticipants);
    final teamRepo = _FakeTeamRepository(
      const TeamInfo(
        id: 'team_test',
        name: 'Mon Équipe',
      ),
    );

    // activeTeamIdProvider is NOT initialized (initialValue: null, simulating F5 browser refresh)
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionsRepositoryProvider.overrideWithValue(repo),
          teamRepositoryProvider.overrideWithValue(teamRepo),
          activeSessionIdProvider.overrideWith((ref) async => 's_test'),
          activeTeamIdProvider.overrideWith(ActiveTeamIdNotifier.new),
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
      ),
    );
    await tester.pumpAndSettle();

    // Must NOT display "Séance introuvable."
    expect(find.text('Séance introuvable.'), findsNothing);
    // Must display the session details
    expect(find.text('Équipe A'), findsWidgets);
    expect(find.text('Équipe B'), findsWidgets);
  });

  testWidgets('SessionDetailScreen active draft session delegates to LiveStatsPanel with pill tabs and no Actif text', (tester) async {
    final draftSession = testSession.copyWith(
      status: SessionStatus.draft,
      teamNames: const {'A': 'Rouge FC', 'B': 'Bleu FC'},
    );
    final repo = _FakeSessionDetailRepository(session: draftSession, participants: testParticipants);

    await tester.pumpWidget(createWidget(repo));
    await tester.pumpAndSettle();

    expect(find.text('Rouge FC'), findsWidgets);
    expect(find.text('Bleu FC'), findsWidgets);
    expect(find.text('Actif'), findsNothing);
    expect(find.byIcon(Remix.check_line), findsNothing);
  });
}
