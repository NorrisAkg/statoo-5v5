import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/data/sessions_repository.dart';
import 'package:statoo/features/sessions/domain/participation.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/domain/session_close_rules.dart';
import 'package:statoo/features/sessions/domain/session_summary.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/team/application/team_provider.dart';

import '../../support/local_shared_service.dart';

class _FakeSessionsRepository implements SessionsRepository {
  _FakeSessionsRepository(this.session, this.participants);

  Session session;
  final List<SessionParticipantDetail> participants;
  int closeCalls = 0;
  bool closeSucceeds = true;
  void Function(Session)? onSaveSession;

  @override
  Future<Session?> getSession(String id, {required String teamId}) async => id == session.id ? session : null;

  @override
  Future<List<SessionParticipantDetail>> getSessionParticipants(String sessionId, {required String teamId}) async => participants;

  @override
  Future<String?> getActiveSessionId({required String teamId}) async => null;

  @override
  Future<void> setActiveSessionId(String? sessionId, {required String teamId}) async {}

  @override
  Future<void> saveSession(
    Session session,
    List<Participation> participations, {
    required String teamId,
  }) async {
    this.session = session;
    onSaveSession?.call(session);
  }

  @override
  Future<void> updateSessionScore({
    required String teamId,
    required String sessionId,
    required int scoreA,
    required int scoreB,
  }) async {
    final res = scoreA > scoreB
        ? MatchResult.teamA
        : scoreB > scoreA
            ? MatchResult.teamB
            : MatchResult.draw;
    session = session.copyWith(scoreA: scoreA, scoreB: scoreB, result: res);
  }

  @override
  Future<bool> closeSession(String sessionId, {required String teamId}) async {
    closeCalls++;
    if (!closeSucceeds) return false;
    session = session.copyWith(status: SessionStatus.closed);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

class _ConcurrentMutatingSqliteRepository extends SqliteSessionsRepository {
  _ConcurrentMutatingSqliteRepository(super._appDatabase, {required this.onAfterReadParticipants});

  final Future<void> Function() onAfterReadParticipants;
  bool _mutated = false;

  @override
  Future<List<SessionParticipantDetail>> getSessionParticipants(
    String sessionId, {
    required String teamId,
  }) async {
    final result = await super.getSessionParticipants(sessionId, teamId: teamId);
    if (!_mutated) {
      _mutated = true;
      await onAfterReadParticipants();
    }
    return result;
  }
}

SessionParticipantDetail _participant(String id, Team team, {int goals = 0, int assists = 0}) => SessionParticipantDetail(
  participation: Participation(id: 'p_$id', sessionId: 's1', playerId: id, team: team, goals: goals, assists: assists),
  playerName: id,
);

/// Balanced teams with 0 goals each — for unscored or 0-0 sessions.
final List<SessionParticipantDetail> _balancedTeams = [
  _participant('a1', Team.a),
  _participant('a2', Team.a),
  _participant('b1', Team.b),
  _participant('b2', Team.b),
];

/// Balanced teams whose goals match scored session (scoreA=2, scoreB=1).
final List<SessionParticipantDetail> _balancedTeamsWithGoals = [
  _participant('a1', Team.a, goals: 1),
  _participant('a2', Team.a, goals: 1),
  _participant('b1', Team.b, goals: 1),
  _participant('b2', Team.b),
];

void main() {
  final playedAt = DateTime(2026, 9, 9, 20, 30);
  final unscored = Session(id: 's1', playedAt: playedAt, isRanked: true);
  final scored = unscored.copyWith(scoreA: 2, scoreB: 1, result: MatchResult.teamA);

  group('closeBlockers', () {
    test('blocks a session whose score was never entered', () {
      expect(
        closeBlockers(session: unscored, teamACount: 5, teamBCount: 5),
        [CloseBlocker.missingScore],
      );
    });

    test('blocks a score without result', () {
      final noResult = unscored.copyWith(scoreA: 0, scoreB: 0);
      expect(closeBlockers(session: noResult, teamACount: 5, teamBCount: 5), [CloseBlocker.missingScore]);
    });

    test('accepts a 0-0 draw once entered', () {
      final draw = unscored.copyWith(scoreA: 0, scoreB: 0, result: MatchResult.draw);
      expect(closeBlockers(session: draw, teamACount: 5, teamBCount: 5), isEmpty);
    });

    test('blocks a team size gap above 1 unless uneven teams are allowed', () {
      expect(closeBlockers(session: scored, teamACount: 6, teamBCount: 4, playerGoalsA: 2, playerGoalsB: 1), [CloseBlocker.unevenTeams]);
      expect(closeBlockers(session: scored, teamACount: 5, teamBCount: 4, playerGoalsA: 2, playerGoalsB: 1), isEmpty);
      expect(
        closeBlockers(session: scored.copyWith(allowUnevenTeams: true), teamACount: 6, teamBCount: 4, playerGoalsA: 2, playerGoalsB: 1),
        isEmpty,
      );
    });

    test('reports every blocker at once', () {
      expect(
        closeBlockers(session: unscored, teamACount: 7, teamBCount: 3),
        [CloseBlocker.missingScore, CloseBlocker.unevenTeams],
      );
    });

    test('blocks when player goals + unassigned do not match the score', () {
      // scored has scoreA=2, scoreB=1, unassignedGoals default to 0
      // playerGoalsA=1 (missing 1 from scoreA=2) → mismatch
      expect(
        closeBlockers(session: scored, teamACount: 5, teamBCount: 5, playerGoalsA: 1, playerGoalsB: 1),
        [CloseBlocker.goalsMismatch],
      );
    });

    test('accepts when player goals + unassigned exactly match the score', () {
      final withUnassigned = scored.copyWith(unassignedGoalsA: 1);
      // scoreA=2: playerGoalsA(1) + unassignedGoalsA(1) = 2 ✓
      // scoreB=1: playerGoalsB(1) + unassignedGoalsB(0) = 1 ✓
      expect(
        closeBlockers(session: withUnassigned, teamACount: 5, teamBCount: 5, playerGoalsA: 1, playerGoalsB: 1),
        isEmpty,
      );
    });

    test('blocks when player goals exceed the score', () {
      expect(
        closeBlockers(session: scored, teamACount: 5, teamBCount: 5, playerGoalsA: 3, playerGoalsB: 1),
        [CloseBlocker.goalsMismatch],
      );
    });

    test('blocks when assists exceed player goals for the session', () {
      // playerGoals: 2 (A) + 1 (B) = 3 goals
      // assists: 2 (A) + 2 (B) = 4 assists > 3 goals
      expect(
        closeBlockers(
          session: scored,
          teamACount: 5,
          teamBCount: 5,
          playerGoalsA: 2,
          playerGoalsB: 1,
          playerAssistsA: 2,
          playerAssistsB: 2,
        ),
        [CloseBlocker.assistsExceedGoals],
      );
    });

    test('accepts when assists are equal to or less than player goals', () {
      // playerGoals: 2 + 1 = 3
      // assists: 2 + 1 = 3 <= 3
      expect(
        closeBlockers(
          session: scored,
          teamACount: 5,
          teamBCount: 5,
          playerGoalsA: 2,
          playerGoalsB: 1,
          playerAssistsA: 2,
          playerAssistsB: 1,
        ),
        isEmpty,
      );
      // assists: 1 + 0 = 1 <= 3
      expect(
        closeBlockers(
          session: scored,
          teamACount: 5,
          teamBCount: 5,
          playerGoalsA: 2,
          playerGoalsB: 1,
          playerAssistsA: 1,
        ),
        isEmpty,
      );
    });

    test('blocks when assists exist on a 0-0 match without player goals', () {
      final draw = unscored.copyWith(scoreA: 0, scoreB: 0, result: MatchResult.draw);
      expect(
        closeBlockers(
          session: draw,
          teamACount: 5,
          teamBCount: 5,
          playerAssistsA: 1,
        ),
        [CloseBlocker.assistsExceedGoals],
      );
    });

    test('blocks when unique scorer is also the unique assister (John auto-passe)', () {
      // Team A has 1 goal scored by John, and John also has 1 assist.
      // John cannot assist himself: goals (1) + assists (1) = 2 > teamGoals (1).
      final oneGoalSession = unscored.copyWith(scoreA: 1, scoreB: 0, result: MatchResult.teamA);
      final participants = [
        _participant('john', Team.a, goals: 1, assists: 1),
        _participant('mate_a', Team.a),
        _participant('b1', Team.b),
        _participant('b2', Team.b),
      ];
      expect(
        closeBlockers(
          session: oneGoalSession,
          teamACount: 2,
          teamBCount: 2,
          playerGoalsA: 1,
          playerAssistsA: 1,
          participations: participants.map((p) => p.participation),
        ),
        [CloseBlocker.selfAssist],
      );
    });

    test('accepts when teammate assists the unique scorer', () {
      // Team A has 1 goal scored by John, assisted by teammate
      final oneGoalSession = unscored.copyWith(scoreA: 1, scoreB: 0, result: MatchResult.teamA);
      final participants = [
        _participant('john', Team.a, goals: 1),
        _participant('mate_a', Team.a, assists: 1),
        _participant('b1', Team.b),
        _participant('b2', Team.b),
      ];
      expect(
        closeBlockers(
          session: oneGoalSession,
          teamACount: 2,
          teamBCount: 2,
          playerGoalsA: 1,
          playerAssistsA: 1,
          participations: participants.map((p) => p.participation),
        ),
        isEmpty,
      );
    });

    test('blocks when a player assists exceed teammate goals in multi-goal match', () {
      // Team A scores 3 goals: John scores 2 goals, Bob scores 1 goal.
      // John has 2 assists. Teammates only scored 1 goal, so John cannot have 2 assists!
      // John: 2 goals + 2 assists = 4 > 3 team goals.
      final threeGoalSession = unscored.copyWith(scoreA: 3, scoreB: 0, result: MatchResult.teamA);
      final participants = [
        _participant('john', Team.a, goals: 2, assists: 2),
        _participant('bob', Team.a, goals: 1),
        _participant('b1', Team.b),
        _participant('b2', Team.b),
      ];
      expect(
        closeBlockers(
          session: threeGoalSession,
          teamACount: 2,
          teamBCount: 2,
          playerGoalsA: 3,
          playerAssistsA: 2,
          participations: participants.map((p) => p.participation),
        ),
        [CloseBlocker.selfAssist],
      );
    });
  });

  group('SessionsController.closeSession', () {
    ProviderContainer containerFor(SessionsRepository repo) {
      final container = ProviderContainer(
        overrides: [
          sharedServiceProvider.overrideWithValue(LocalTestSharedService()),
          sessionsRepositoryProvider.overrideWithValue(repo),
          activeTeamIdProvider.overrideWith(() => ActiveTeamIdNotifier(initialValue: 't1')),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('refuses to close without a score, whatever the screen checked', () async {
      final repo = _FakeSessionsRepository(unscored, _balancedTeams);
      final blockers = await containerFor(repo).read(sessionsControllerProvider).closeSession('s1');

      expect(blockers, [CloseBlocker.missingScore]);
      expect(repo.closeCalls, 0);
      expect(repo.session.status, SessionStatus.draft);
    });

    test('closes a scored session with balanced teams', () async {
      final repo = _FakeSessionsRepository(scored, _balancedTeamsWithGoals);
      final blockers = await containerFor(repo).read(sessionsControllerProvider).closeSession('s1');

      expect(blockers, isEmpty);
      expect(repo.closeCalls, 1);
      expect(repo.session.status, SessionStatus.closed);
    });

    test('reports a refused write instead of claiming success', () async {
      final repo = _FakeSessionsRepository(scored, _balancedTeamsWithGoals)..closeSucceeds = false;
      final controller = containerFor(repo).read(sessionsControllerProvider);

      await expectLater(controller.closeSession('s1'), throwsA(isA<SessionCloseException>()));
      expect(repo.session.status, SessionStatus.draft);
    });

    test('closes a session on a 0-0 goalless draw (score nul et vierge)', () async {
      final zeroZeroDraw = unscored.copyWith(scoreA: 0, scoreB: 0, result: MatchResult.draw);
      final repo = _FakeSessionsRepository(zeroZeroDraw, _balancedTeams);
      final blockers = await containerFor(repo).read(sessionsControllerProvider).closeSession('s1');

      expect(blockers, isEmpty);
      expect(repo.closeCalls, 1);
      expect(repo.session.status, SessionStatus.closed);
    });

    test('refuses to close when team assists exceed team player goals', () async {
      // scoreA=2, scoreB=1. Team A has 3 assists across non-scorers (no self-assist: 0+1 <= 2).
      // playerAssistsA: 1 + 1 + 1 = 3 > playerGoalsA: 2
      final scored5v5 = unscored.copyWith(scoreA: 2, scoreB: 1, result: MatchResult.teamA);
      final teamsWithExcessAssists = [
        _participant('a1', Team.a, goals: 1),
        _participant('a2', Team.a, goals: 1),
        _participant('a3', Team.a, assists: 1),
        _participant('a4', Team.a, assists: 1),
        _participant('a5', Team.a, assists: 1),
        _participant('b1', Team.b, goals: 1),
        _participant('b2', Team.b),
        _participant('b3', Team.b),
        _participant('b4', Team.b),
        _participant('b5', Team.b),
      ];
      final repo = _FakeSessionsRepository(scored5v5, teamsWithExcessAssists);
      final blockers = await containerFor(repo).read(sessionsControllerProvider).closeSession('s1');

      expect(blockers, [CloseBlocker.assistsExceedGoals]);
      expect(repo.closeCalls, 0);
      expect(repo.session.status, SessionStatus.draft);
    });

    test('refuses to close when a player is credited with a self-assist (John)', () async {
      // 1-0 match: John is unique scorer and unique assister for Team A.
      // Team assists = 1 <= 1, but John has 1 goal + 1 assist = 2 > 1.
      final oneZeroMatch = unscored.copyWith(scoreA: 1, scoreB: 0, result: MatchResult.teamA);
      final teamsWithSelfAssist = [
        _participant('john', Team.a, goals: 1, assists: 1),
        _participant('mate_a', Team.a),
        _participant('b1', Team.b),
        _participant('b2', Team.b),
      ];
      final repo = _FakeSessionsRepository(oneZeroMatch, teamsWithSelfAssist);
      final blockers = await containerFor(repo).read(sessionsControllerProvider).closeSession('s1');

      expect(blockers, [CloseBlocker.selfAssist]);
      expect(repo.closeCalls, 0);
      expect(repo.session.status, SessionStatus.draft);
    });
  });

  group('SessionsController.createDraftSession', () {
    ProviderContainer containerFor(SessionsRepository repo) {
      final container = ProviderContainer(
        overrides: [
          sharedServiceProvider.overrideWithValue(LocalTestSharedService()),
          sessionsRepositoryProvider.overrideWithValue(repo),
          activeTeamIdProvider.overrideWith(() => ActiveTeamIdNotifier(initialValue: 't1')),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('initializes new session score to 0 - 0 with draw result', () async {
      Session? savedSession;
      final repo = _FakeSessionsRepository(unscored, _balancedTeams)
        ..onSaveSession = (s) => savedSession = s;
      final container = containerFor(repo);

      await container.read(sessionsControllerProvider).createDraftSession(
        playedAt: playedAt,
        isRanked: true,
        allowUnevenTeams: false,
        playerTeamAssignments: {'a1': 'A', 'b1': 'B'},
      );

      expect(savedSession, isNotNull);
      expect(savedSession!.scoreA, 0);
      expect(savedSession!.scoreB, 0);
      expect(savedSession!.result, MatchResult.draw);
    });
  });

  group('SessionsController.startSession', () {
    ProviderContainer containerFor(SessionsRepository repo) {
      final container = ProviderContainer(
        overrides: [
          sharedServiceProvider.overrideWithValue(LocalTestSharedService()),
          sessionsRepositoryProvider.overrideWithValue(repo),
          activeTeamIdProvider.overrideWith(() => ActiveTeamIdNotifier(initialValue: 't1')),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('initializes unscored session to 0 - 0 with draw when starting', () async {
      final repo = _FakeSessionsRepository(unscored, _balancedTeams);
      final container = containerFor(repo);

      final success = await container.read(sessionsControllerProvider).startSession('s1');

      expect(success, isTrue);
      expect(repo.session.scoreA, 0);
      expect(repo.session.scoreB, 0);
      expect(repo.session.result, MatchResult.draw);
    });
  });

  group('SPORT-01 — Atomic SQLite Session Close (SPORT01-S01..S15)', () {
    late Database db;
    late AppDatabase appDb;
    late SqliteSessionsRepository sqliteRepo;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 8,
          onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON;'),
        ),
      );
      appDb = AppDatabase.forTesting(db);
      await appDb.initSchemaForTest(db);
      sqliteRepo = SqliteSessionsRepository(appDb);

      final now = DateTime(2026, 10, 30).toIso8601String();
      for (final t in ['t1', 't2']) {
        await db.insert('teams', {
          'id': t,
          'name': 'Team $t',
          'format': '5v5',
          'created_at': now,
        });
      }
      for (final p in ['a1', 'a2', 'a3', 'a4', 'b1', 'b2', 'b3', 'c1', 'c2']) {
        await db.insert('players', {
          'id': p,
          'team_id': 't1',
          'name': 'Player $p',
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        });
      }
      for (final p in ['t2_a1', 't2_b1']) {
        await db.insert('players', {
          'id': p,
          'team_id': 't2',
          'name': 'Player $p',
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        });
      }
    });

    tearDown(() async {
      await db.close();
    });

    ProviderContainer sqliteContainer({
      String? activeTeamId = 't1',
      SessionsRepository? repoOverride,
    }) {
      final container = ProviderContainer(
        overrides: [
          sharedServiceProvider.overrideWithValue(LocalTestSharedService()),
          sessionsRepositoryProvider.overrideWithValue(repoOverride ?? sqliteRepo),
          activeTeamIdProvider.overrideWith(
            () => ActiveTeamIdNotifier(initialValue: activeTeamId),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('SPORT01-S01: nominal classic 2-team session closes atomically and clears active_session_id', () async {
      final s1 = Session(
        id: 's1',
        playedAt: playedAt,
        scoreA: 3,
        scoreB: 2,
        result: MatchResult.teamA,
      );
      final parts = [
        const Participation(id: 'p1', sessionId: 's1', playerId: 'a1', team: Team.a, goals: 2, assists: 1),
        const Participation(id: 'p2', sessionId: 's1', playerId: 'a2', team: Team.a, goals: 1, assists: 1),
        const Participation(id: 'p3', sessionId: 's1', playerId: 'a3', team: Team.a),
        const Participation(id: 'p4', sessionId: 's1', playerId: 'b1', team: Team.b, goals: 2),
        const Participation(id: 'p5', sessionId: 's1', playerId: 'b2', team: Team.b, assists: 1),
        const Participation(id: 'p6', sessionId: 's1', playerId: 'b3', team: Team.b),
      ];
      await sqliteRepo.saveSession(s1, parts, teamId: 't1');
      await sqliteRepo.setActiveSessionId('s1', teamId: 't1');

      final blockers = await sqliteContainer().read(sessionsControllerProvider).closeSession('s1');

      expect(blockers, isEmpty);
      final after = await sqliteRepo.getSession('s1', teamId: 't1');
      expect(after?.status, SessionStatus.closed);
      expect(after?.result, MatchResult.teamA);
      expect(await sqliteRepo.getActiveSessionId(teamId: 't1'), isNull);
    });

    test('SPORT01-S02: nominal 3-team tournament computes result and closes atomically in one transaction', () async {
      final s1 = Session(
        id: 's_tour_1',
        playedAt: playedAt,
        sessionType: SessionType.tournament3,
        winsA: 2,
        winsB: 1,
      );
      final parts = [
        const Participation(id: 'p1', sessionId: 's_tour_1', playerId: 'a1', team: Team.a),
        const Participation(id: 'p2', sessionId: 's_tour_1', playerId: 'a2', team: Team.a),
        const Participation(id: 'p3', sessionId: 's_tour_1', playerId: 'b1', team: Team.b),
        const Participation(id: 'p4', sessionId: 's_tour_1', playerId: 'b2', team: Team.b),
        const Participation(id: 'p5', sessionId: 's_tour_1', playerId: 'c1', team: Team.c),
        const Participation(id: 'p6', sessionId: 's_tour_1', playerId: 'c2', team: Team.c),
      ];
      await sqliteRepo.saveSession(s1, parts, teamId: 't1');
      await sqliteRepo.setActiveSessionId('s_tour_1', teamId: 't1');

      // Direct repository call must also compute tournament result and validate atomically
      final closed = await sqliteRepo.closeSession('s_tour_1', teamId: 't1');
      expect(closed, isTrue);

      final after = await sqliteRepo.getSession('s_tour_1', teamId: 't1');
      expect(after?.status, SessionStatus.closed);
      expect(after?.result, MatchResult.teamA);
      expect(await sqliteRepo.getActiveSessionId(teamId: 't1'), isNull);
    });

    test('SPORT01-S03: tournament ties (drawAB and drawAll) are computed and persisted atomically', () async {
      final sDrawAB = Session(
        id: 's_draw_ab',
        playedAt: playedAt,
        sessionType: SessionType.tournament3,
        winsA: 2,
        winsB: 2,
        winsC: 1,
      );
      final partsAB = [
        const Participation(id: 'p1', sessionId: 's_draw_ab', playerId: 'a1', team: Team.a),
        const Participation(id: 'p2', sessionId: 's_draw_ab', playerId: 'b1', team: Team.b),
        const Participation(id: 'p3', sessionId: 's_draw_ab', playerId: 'c1', team: Team.c),
      ];
      await sqliteRepo.saveSession(sDrawAB, partsAB, teamId: 't1');

      final blockersAB = await sqliteContainer().read(sessionsControllerProvider).closeSession('s_draw_ab');
      expect(blockersAB, isEmpty);
      final afterAB = await sqliteRepo.getSession('s_draw_ab', teamId: 't1');
      expect(afterAB?.status, SessionStatus.closed);
      expect(afterAB?.result, MatchResult.drawAB);

      final sDrawAll = Session(
        id: 's_draw_all',
        playedAt: playedAt,
        sessionType: SessionType.tournament3,
        winsA: 1,
        winsB: 1,
        winsC: 1,
      );
      final partsAll = [
        const Participation(id: 'p4', sessionId: 's_draw_all', playerId: 'a1', team: Team.a),
        const Participation(id: 'p5', sessionId: 's_draw_all', playerId: 'b1', team: Team.b),
        const Participation(id: 'p6', sessionId: 's_draw_all', playerId: 'c1', team: Team.c),
      ];
      await sqliteRepo.saveSession(sDrawAll, partsAll, teamId: 't1');

      final blockersAll = await sqliteContainer().read(sessionsControllerProvider).closeSession('s_draw_all');
      expect(blockersAll, isEmpty);
      final afterAll = await sqliteRepo.getSession('s_draw_all', teamId: 't1');
      expect(afterAll?.status, SessionStatus.closed);
      expect(afterAll?.result, MatchResult.drawAll);
    });

    test('SPORT01-S04: closing a non-active DRAFT session preserves active_session_id of another active session', () async {
      final s1 = Session(id: 's1', playedAt: playedAt, scoreA: 1, scoreB: 0, result: MatchResult.teamA);
      final s2 = Session(id: 's2', playedAt: playedAt, scoreA: 0, scoreB: 0, result: MatchResult.draw);
      await sqliteRepo.saveSession(
        s1,
        const [
          Participation(id: 'p1', sessionId: 's1', playerId: 'a1', team: Team.a, goals: 1),
          Participation(id: 'p2', sessionId: 's1', playerId: 'b1', team: Team.b),
        ],
        teamId: 't1',
      );
      await sqliteRepo.saveSession(
        s2,
        const [
          Participation(id: 'p3', sessionId: 's2', playerId: 'a1', team: Team.a),
          Participation(id: 'p4', sessionId: 's2', playerId: 'b1', team: Team.b),
        ],
        teamId: 't1',
      );
      await sqliteRepo.setActiveSessionId('s2', teamId: 't1');

      final blockers = await sqliteContainer().read(sessionsControllerProvider).closeSession('s1');
      expect(blockers, isEmpty);
      expect((await sqliteRepo.getSession('s1', teamId: 't1'))?.status, SessionStatus.closed);
      expect(await sqliteRepo.getActiveSessionId(teamId: 't1'), 's2');
    });

    test('SPORT01-S05: uneven teams (4v2) close atomically when allowUnevenTeams is true', () async {
      final s1 = Session(
        id: 's_uneven_ok',
        playedAt: playedAt,
        allowUnevenTeams: true,
        scoreA: 1,
        scoreB: 0,
        result: MatchResult.teamA,
      );
      final parts = [
        const Participation(id: 'p1', sessionId: 's_uneven_ok', playerId: 'a1', team: Team.a, goals: 1),
        const Participation(id: 'p2', sessionId: 's_uneven_ok', playerId: 'a2', team: Team.a),
        const Participation(id: 'p3', sessionId: 's_uneven_ok', playerId: 'a3', team: Team.a),
        const Participation(id: 'p4', sessionId: 's_uneven_ok', playerId: 'a4', team: Team.a),
        const Participation(id: 'p5', sessionId: 's_uneven_ok', playerId: 'b1', team: Team.b),
        const Participation(id: 'p6', sessionId: 's_uneven_ok', playerId: 'b2', team: Team.b),
      ];
      await sqliteRepo.saveSession(s1, parts, teamId: 't1');

      final blockers = await sqliteContainer().read(sessionsControllerProvider).closeSession('s_uneven_ok');
      expect(blockers, isEmpty);
      expect((await sqliteRepo.getSession('s_uneven_ok', teamId: 't1'))?.status, SessionStatus.closed);
    });

    test('SPORT01-S06: missing score in classic or 0-0-0 tournament blocks close and leaves SQLite untouched', () async {
      final sClassic = Session(id: 's_no_score', playedAt: playedAt);
      await sqliteRepo.saveSession(
        sClassic,
        const [
          Participation(id: 'p1', sessionId: 's_no_score', playerId: 'a1', team: Team.a),
          Participation(id: 'p2', sessionId: 's_no_score', playerId: 'b1', team: Team.b),
        ],
        teamId: 't1',
      );
      await sqliteRepo.setActiveSessionId('s_no_score', teamId: 't1');

      final blockersClassic = await sqliteContainer().read(sessionsControllerProvider).closeSession('s_no_score');
      expect(blockersClassic, [CloseBlocker.missingScore]);
      expect(await sqliteRepo.closeSession('s_no_score', teamId: 't1'), isFalse);
      expect((await sqliteRepo.getSession('s_no_score', teamId: 't1'))?.status, SessionStatus.draft);
      expect(await sqliteRepo.getActiveSessionId(teamId: 't1'), 's_no_score');

      final sTour = Session(
        id: 's_tour_000',
        playedAt: playedAt,
        sessionType: SessionType.tournament3,
      );
      await sqliteRepo.saveSession(
        sTour,
        const [
          Participation(id: 'p3', sessionId: 's_tour_000', playerId: 'a1', team: Team.a),
          Participation(id: 'p4', sessionId: 's_tour_000', playerId: 'b1', team: Team.b),
          Participation(id: 'p5', sessionId: 's_tour_000', playerId: 'c1', team: Team.c),
        ],
        teamId: 't1',
      );
      final blockersTour = await sqliteContainer().read(sessionsControllerProvider).closeSession('s_tour_000');
      expect(blockersTour, [CloseBlocker.missingScore]);
      expect((await sqliteRepo.getSession('s_tour_000', teamId: 't1'))?.result, isNull);
      expect((await sqliteRepo.getSession('s_tour_000', teamId: 't1'))?.status, SessionStatus.draft);
    });

    test('SPORT01-S07: unevenTeams in SQLite blocks close (both repo and controller) and does not mutate tournament result', () async {
      // Classic 3v1 without allowUnevenTeams
      final sClassic = Session(
        id: 's_uneven_classic',
        playedAt: playedAt,
        scoreA: 1,
        scoreB: 0,
        result: MatchResult.teamA,
      );
      await sqliteRepo.saveSession(
        sClassic,
        const [
          Participation(id: 'p1', sessionId: 's_uneven_classic', playerId: 'a1', team: Team.a, goals: 1),
          Participation(id: 'p2', sessionId: 's_uneven_classic', playerId: 'a2', team: Team.a),
          Participation(id: 'p3', sessionId: 's_uneven_classic', playerId: 'a3', team: Team.a),
          Participation(id: 'p4', sessionId: 's_uneven_classic', playerId: 'b1', team: Team.b),
        ],
        teamId: 't1',
      );
      await sqliteRepo.setActiveSessionId('s_uneven_classic', teamId: 't1');

      // Direct repository call MUST refuse to close a session with unevenTeams blocker
      expect(await sqliteRepo.closeSession('s_uneven_classic', teamId: 't1'), isFalse);
      expect((await sqliteRepo.getSession('s_uneven_classic', teamId: 't1'))?.status, SessionStatus.draft);
      expect(await sqliteRepo.getActiveSessionId(teamId: 't1'), 's_uneven_classic');

      // Tournament 3v1v1 with winsA=2, winsB=1, winsC=0 and result=null initially
      final sTour = Session(
        id: 's_uneven_tour',
        playedAt: playedAt,
        sessionType: SessionType.tournament3,
        winsA: 2,
        winsB: 1,
      );
      await sqliteRepo.saveSession(
        sTour,
        const [
          Participation(id: 'pt1', sessionId: 's_uneven_tour', playerId: 'a1', team: Team.a),
          Participation(id: 'pt2', sessionId: 's_uneven_tour', playerId: 'a2', team: Team.a),
          Participation(id: 'pt3', sessionId: 's_uneven_tour', playerId: 'a3', team: Team.a),
          Participation(id: 'pt4', sessionId: 's_uneven_tour', playerId: 'b1', team: Team.b),
          Participation(id: 'pt5', sessionId: 's_uneven_tour', playerId: 'c1', team: Team.c),
        ],
        teamId: 't1',
      );

      final blockers = await sqliteContainer().read(sessionsControllerProvider).closeSession('s_uneven_tour');
      expect(blockers, [CloseBlocker.unevenTeams]);
      final tourAfter = await sqliteRepo.getSession('s_uneven_tour', teamId: 't1');
      expect(tourAfter?.status, SessionStatus.draft);
      expect(tourAfter?.result, isNull);
    });

    test('SPORT01-S08: goalsMismatch in SQLite blocks close in both repository and controller without mutating DB', () async {
      final s1 = Session(
        id: 's_mismatch',
        playedAt: playedAt,
        scoreA: 3,
        scoreB: 1,
        result: MatchResult.teamA,
      );
      await sqliteRepo.saveSession(
        s1,
        const [
          Participation(id: 'p1', sessionId: 's_mismatch', playerId: 'a1', team: Team.a, goals: 2),
          Participation(id: 'p2', sessionId: 's_mismatch', playerId: 'b1', team: Team.b, goals: 1),
        ],
        teamId: 't1',
      );
      await sqliteRepo.setActiveSessionId('s_mismatch', teamId: 't1');

      expect(await sqliteRepo.closeSession('s_mismatch', teamId: 't1'), isFalse);
      final blockers = await sqliteContainer().read(sessionsControllerProvider).closeSession('s_mismatch');
      expect(blockers, [CloseBlocker.goalsMismatch]);
      expect((await sqliteRepo.getSession('s_mismatch', teamId: 't1'))?.status, SessionStatus.draft);
      expect(await sqliteRepo.getActiveSessionId(teamId: 't1'), 's_mismatch');
    });

    test('SPORT01-S09: assistsExceedGoals in SQLite blocks close in both repository and controller without mutating DB', () async {
      final s1 = Session(
        id: 's_assists',
        playedAt: playedAt,
        scoreA: 2,
        scoreB: 0,
        unassignedGoalsA: 1,
        result: MatchResult.teamA,
      );
      await sqliteRepo.saveSession(
        s1,
        const [
          Participation(id: 'p1', sessionId: 's_assists', playerId: 'a1', team: Team.a, goals: 1),
          Participation(id: 'p2', sessionId: 's_assists', playerId: 'a2', team: Team.a, assists: 1),
          Participation(id: 'p3', sessionId: 's_assists', playerId: 'a3', team: Team.a, assists: 1),
          Participation(id: 'p4', sessionId: 's_assists', playerId: 'b1', team: Team.b),
          Participation(id: 'p5', sessionId: 's_assists', playerId: 'b2', team: Team.b),
        ],
        teamId: 't1',
      );

      expect(await sqliteRepo.closeSession('s_assists', teamId: 't1'), isFalse);
      final blockers = await sqliteContainer().read(sessionsControllerProvider).closeSession('s_assists');
      expect(blockers, [CloseBlocker.assistsExceedGoals]);
      expect((await sqliteRepo.getSession('s_assists', teamId: 't1'))?.status, SessionStatus.draft);
    });

    test('SPORT01-S10: selfAssist in SQLite blocks close in both repository and controller without mutating DB', () async {
      final s1 = Session(
        id: 's_self_assist',
        playedAt: playedAt,
        scoreA: 2,
        scoreB: 0,
        result: MatchResult.teamA,
      );
      await sqliteRepo.saveSession(
        s1,
        const [
          Participation(id: 'p1', sessionId: 's_self_assist', playerId: 'a1', team: Team.a, goals: 2, assists: 1),
          Participation(id: 'p2', sessionId: 's_self_assist', playerId: 'a2', team: Team.a),
          Participation(id: 'p3', sessionId: 's_self_assist', playerId: 'b1', team: Team.b),
          Participation(id: 'p4', sessionId: 's_self_assist', playerId: 'b2', team: Team.b),
        ],
        teamId: 't1',
      );

      expect(await sqliteRepo.closeSession('s_self_assist', teamId: 't1'), isFalse);
      final blockers = await sqliteContainer().read(sessionsControllerProvider).closeSession('s_self_assist');
      expect(blockers, [CloseBlocker.selfAssist]);
      expect((await sqliteRepo.getSession('s_self_assist', teamId: 't1'))?.status, SessionStatus.draft);
    });

    test('SPORT01-S11: duplicate player in participations is detected and blocks close', () {
      final s1 = Session(
        id: 's_dup',
        playedAt: playedAt,
        scoreA: 1,
        scoreB: 0,
        result: MatchResult.teamA,
      );
      final duplicateParticipations = [
        const Participation(id: 'p1', sessionId: 's_dup', playerId: 'a1', team: Team.a, goals: 1),
        const Participation(id: 'p2', sessionId: 's_dup', playerId: 'a1', team: Team.b),
      ];
      final blockers = closeBlockers(
        session: s1,
        teamACount: 1,
        teamBCount: 1,
        playerGoalsA: 1,
        participations: duplicateParticipations,
      );
      expect(blockers, [CloseBlocker.duplicatePlayer]);
    });

    test('SPORT01-S12: TOCTOU concurrent SQLite mutation between read and transaction is caught atomically', () async {
      final s1 = Session(
        id: 's_toctou',
        playedAt: playedAt,
        scoreA: 1,
        scoreB: 0,
        result: MatchResult.teamA,
      );
      await sqliteRepo.saveSession(
        s1,
        const [
          Participation(id: 'p1', sessionId: 's_toctou', playerId: 'a1', team: Team.a, goals: 1),
          Participation(id: 'p2', sessionId: 's_toctou', playerId: 'b1', team: Team.b),
        ],
        teamId: 't1',
      );
      await sqliteRepo.setActiveSessionId('s_toctou', teamId: 't1');

      // Repository wrapper that mutates score_a = 3 in SQLite right after controller reads participants
      final concurrentRepo = _ConcurrentMutatingSqliteRepository(
        appDb,
        onAfterReadParticipants: () async {
          await db.update(
            'sessions',
            {'score_a': 3},
            where: 'id = ?',
            whereArgs: ['s_toctou'],
          );
        },
      );

      final controller = sqliteContainer(repoOverride: concurrentRepo).read(sessionsControllerProvider);
      try {
        final blockers = await controller.closeSession('s_toctou');
        expect(blockers, [CloseBlocker.goalsMismatch]);
      } on SessionCloseException {
        // Also acceptable if concurrent write is rejected with SessionCloseException
      }

      // Most importantly: the invalid session MUST NOT have been closed in SQLite!
      expect((await sqliteRepo.getSession('s_toctou', teamId: 't1'))?.status, SessionStatus.draft);
      expect(await sqliteRepo.getActiveSessionId(teamId: 't1'), 's_toctou');
    });

    test('SPORT01-S13: closing an already CLOSED or unknown session throws SessionCloseException without side effects', () async {
      final sClosed = Session(
        id: 's_already_closed',
        playedAt: playedAt,
        status: SessionStatus.closed,
        scoreA: 1,
        scoreB: 0,
        result: MatchResult.teamA,
      );
      await sqliteRepo.saveSession(
        sClosed,
        const [
          Participation(id: 'p1', sessionId: 's_already_closed', playerId: 'a1', team: Team.a, goals: 1),
          Participation(id: 'p2', sessionId: 's_already_closed', playerId: 'b1', team: Team.b),
        ],
        teamId: 't1',
      );
      await sqliteRepo.saveSession(
        Session(id: 's_other', playedAt: playedAt),
        const [],
        teamId: 't1',
      );
      await sqliteRepo.setActiveSessionId('s_other', teamId: 't1');

      final controller = sqliteContainer().read(sessionsControllerProvider);
      await expectLater(
        controller.closeSession('s_already_closed'),
        throwsA(isA<SessionCloseException>()),
      );
      await expectLater(
        controller.closeSession('s_non_existent'),
        throwsA(isA<SessionCloseException>()),
      );
      expect(await sqliteRepo.getActiveSessionId(teamId: 't1'), 's_other');
    });

    test('SPORT01-S14: multi-tenant isolation prevents team t2 from closing team t1 session', () async {
      final s1 = Session(
        id: 's_t1',
        playedAt: playedAt,
        scoreA: 1,
        scoreB: 0,
        result: MatchResult.teamA,
      );
      await sqliteRepo.saveSession(
        s1,
        const [
          Participation(id: 'p1', sessionId: 's_t1', playerId: 'a1', team: Team.a, goals: 1),
          Participation(id: 'p2', sessionId: 's_t1', playerId: 'b1', team: Team.b),
        ],
        teamId: 't1',
      );
      await sqliteRepo.setActiveSessionId('s_t1', teamId: 't1');

      // Direct repo call as t2
      expect(await sqliteRepo.closeSession('s_t1', teamId: 't2'), isFalse);

      // Controller call as t2
      final controllerT2 = sqliteContainer(activeTeamId: 't2').read(sessionsControllerProvider);
      await expectLater(
        controllerT2.closeSession('s_t1'),
        throwsA(isA<SessionCloseException>()),
      );

      expect((await sqliteRepo.getSession('s_t1', teamId: 't1'))?.status, SessionStatus.draft);
      expect(await sqliteRepo.getActiveSessionId(teamId: 't1'), 's_t1');
    });

    test('SPORT01-S15: closeSession with null activeTeamId throws StateError immediately', () async {
      final controllerNoTeam = sqliteContainer(activeTeamId: null).read(sessionsControllerProvider);
      await expectLater(
        controllerNoTeam.closeSession('s1'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
