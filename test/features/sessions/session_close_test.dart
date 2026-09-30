import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/data/sessions_repository.dart';
import 'package:statoo/features/sessions/domain/participation.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/domain/session_close_rules.dart';
import 'package:statoo/features/sessions/domain/session_summary.dart';
import 'package:statoo/features/team/application/team_provider.dart';

class _FakeSessionsRepository implements SessionsRepository {
  _FakeSessionsRepository(this.session, this.participants);

  Session session;
  final List<SessionParticipantDetail> participants;
  int closeCalls = 0;
  bool closeSucceeds = true;
  void Function(Session)? onSaveSession;

  @override
  Future<Session?> getSession(String id) async => id == session.id ? session : null;

  @override
  Future<List<SessionParticipantDetail>> getSessionParticipants(String sessionId) async => participants;

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
        closeBlockers(session: unscored, teamACount: 5, teamBCount: 5, playerGoalsA: 0, playerGoalsB: 0),
        [CloseBlocker.missingScore],
      );
    });

    test('blocks a score without result', () {
      final noResult = unscored.copyWith(scoreA: 0, scoreB: 0);
      expect(closeBlockers(session: noResult, teamACount: 5, teamBCount: 5, playerGoalsA: 0, playerGoalsB: 0), [CloseBlocker.missingScore]);
    });

    test('accepts a 0-0 draw once entered', () {
      final draw = unscored.copyWith(scoreA: 0, scoreB: 0, result: MatchResult.draw);
      expect(closeBlockers(session: draw, teamACount: 5, teamBCount: 5, playerGoalsA: 0, playerGoalsB: 0), isEmpty);
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
        closeBlockers(session: unscored, teamACount: 7, teamBCount: 3, playerGoalsA: 0, playerGoalsB: 0),
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
          playerGoalsA: 0,
          playerGoalsB: 0,
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
          playerGoalsB: 0,
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
          playerGoalsB: 0,
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
          playerGoalsB: 0,
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
}
