import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import '../../support/local_shared_service.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/data/sessions_repository.dart';
import 'package:statoo/features/sessions/domain/participation.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/domain/session_close_rules.dart';
import 'package:statoo/features/sessions/domain/session_summary.dart';
import 'package:statoo/features/stats/domain/stats_calculator.dart';
import 'package:statoo/features/team/application/team_provider.dart';

class _FakeTournamentRepository implements SessionsRepository {
  _FakeTournamentRepository(this.session, this.participants);

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
  Future<void> updateTournamentWins({
    required String teamId,
    required String sessionId,
    required int winsA,
    required int winsB,
    required int winsC,
    MatchResult? result,
  }) async {
    session = session.copyWith(winsA: winsA, winsB: winsB, winsC: winsC, result: result);
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

SessionParticipantDetail _part(String id, Team team) => SessionParticipantDetail(
      participation: Participation(id: 'p_$id', sessionId: 's1', playerId: id, team: team),
      playerName: id,
    );

void main() {
  final playedAt = DateTime(2026, 9, 30, 20);

  group('Tournament 3 Teams - closeBlockers', () {
    final baseTournament = Session(
      id: 's_tourn',
      playedAt: playedAt,
      sessionType: SessionType.tournament3,
      isRanked: true,
      winsA: 3,
      winsB: 2,
      winsC: 1,
      result: MatchResult.teamA,
    );

    test('accepts perfectly balanced 15 players (5-5-5)', () {
      final blockers = closeBlockers(
        session: baseTournament,
        teamACount: 5,
        teamBCount: 5,
        teamCCount: 5,
      );
      expect(blockers, isEmpty);
    });

    test('accepts surplus 16 players (6-5-5)', () {
      final blockers = closeBlockers(
        session: baseTournament,
        teamACount: 6,
        teamBCount: 5,
        teamCCount: 5,
      );
      expect(blockers, isEmpty);
    });

    test('accepts surplus 17 players (6-6-5)', () {
      final blockers = closeBlockers(
        session: baseTournament,
        teamACount: 6,
        teamBCount: 6,
        teamCCount: 5,
      );
      expect(blockers, isEmpty);
    });

    test('blocks team gap > 1 unless uneven allowed (e.g. 7-5-5)', () {
      final blocked = closeBlockers(
        session: baseTournament,
        teamACount: 7,
        teamBCount: 5,
        teamCCount: 5,
      );
      expect(blocked, [CloseBlocker.unevenTeams]);

      final allowed = closeBlockers(
        session: baseTournament.copyWith(allowUnevenTeams: true),
        teamACount: 7,
        teamBCount: 5,
        teamCCount: 5,
      );
      expect(allowed, isEmpty);
    });

    test('blocks when tournament has no result decided yet', () {
      final noResult = baseTournament.copyWith(result: null);
      final blockers = closeBlockers(
        session: noResult,
        teamACount: 5,
        teamBCount: 5,
        teamCCount: 5,
      );
      expect(blockers, [CloseBlocker.missingScore]);
    });
  });

  group('Tournament 3 Teams - StatsCalculator', () {
    final parts = [
      const Participation(id: 'pt_a', sessionId: 's1', playerId: 'p_a', team: Team.a),
      const Participation(id: 'pt_b', sessionId: 's1', playerId: 'p_b', team: Team.b),
      const Participation(id: 'pt_c', sessionId: 's1', playerId: 'p_c', team: Team.c),
    ];

    test('Clean win for Team C gives 3 pts to Team C, 0 to Team A and B', () {
      final session = Session(
        id: 's1',
        playedAt: playedAt,
        status: SessionStatus.closed,
        sessionType: SessionType.tournament3,
        isRanked: true,
        winsA: 1,
        winsB: 2,
        winsC: 4,
        result: MatchResult.teamC,
      );

      final stats = StatsCalculator.computePlayerStats([session], parts);
      final pA = stats.firstWhere((s) => s.playerId == 'p_a');
      final pB = stats.firstWhere((s) => s.playerId == 'p_b');
      final pC = stats.firstWhere((s) => s.playerId == 'p_c');

      expect(pC.totalPoints, 3);
      expect(pC.wins, 1);
      expect(pC.losses, 0);

      expect(pA.totalPoints, 0);
      expect(pA.losses, 1);

      expect(pB.totalPoints, 0);
      expect(pB.losses, 1);
    });

    test('Tie between Team A and B (drawAB) with default 1 point', () {
      final session = Session(
        id: 's1',
        playedAt: playedAt,
        status: SessionStatus.closed,
        sessionType: SessionType.tournament3,
        isRanked: true,
        winsA: 3,
        winsB: 3,
        winsC: 1,
        result: MatchResult.drawAB,
      );

      final stats = StatsCalculator.computePlayerStats([session], parts);
      final pA = stats.firstWhere((s) => s.playerId == 'p_a');
      final pB = stats.firstWhere((s) => s.playerId == 'p_b');
      final pC = stats.firstWhere((s) => s.playerId == 'p_c');

      expect(pA.totalPoints, 1);
      expect(pA.draws, 1);
      expect(pA.losses, 0);

      expect(pB.totalPoints, 1);
      expect(pB.draws, 1);
      expect(pB.losses, 0);

      expect(pC.totalPoints, 0);
      expect(pC.losses, 1);
    });

    test('Tie between Team A and B (drawAB) with configured 2 points', () {
      final session = Session(
        id: 's1',
        playedAt: playedAt,
        status: SessionStatus.closed,
        sessionType: SessionType.tournament3,
        isRanked: true,
        drawPoints: 2,
        winsA: 4,
        winsB: 4,
        winsC: 2,
        result: MatchResult.drawAB,
      );

      final stats = StatsCalculator.computePlayerStats([session], parts);
      final pA = stats.firstWhere((s) => s.playerId == 'p_a');
      final pB = stats.firstWhere((s) => s.playerId == 'p_b');
      final pC = stats.firstWhere((s) => s.playerId == 'p_c');

      expect(pA.totalPoints, 2);
      expect(pA.draws, 1);
      expect(pA.wins, 0);

      expect(pB.totalPoints, 2);
      expect(pB.draws, 1);

      expect(pC.totalPoints, 0);
      expect(pC.losses, 1);
    });

    test('Three-way tie (drawAll) awards configured points to all 3 teams', () {
      final session = Session(
        id: 's1',
        playedAt: playedAt,
        status: SessionStatus.closed,
        sessionType: SessionType.tournament3,
        isRanked: true,
        drawPoints: 2,
        winsA: 2,
        winsB: 2,
        winsC: 2,
        result: MatchResult.drawAll,
      );

      final stats = StatsCalculator.computePlayerStats([session], parts);
      for (final s in stats) {
        expect(s.totalPoints, 2);
        expect(s.draws, 1);
        expect(s.losses, 0);
      }
    });
  });

  group('SessionsController - Tournament 3 Teams', () {
    ProviderContainer containerFor(SessionsRepository repo) {
      final container = ProviderContainer(
        overrides: [
          sharedServiceProvider.overrideWithValue(LocalTestSharedService()),
          sessionsRepositoryProvider.overrideWithValue(repo),
          activeTeamIdProvider.overrideWith(() => ActiveTeamIdNotifier(initialValue: 'team_urban')),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('createDraftSession with tournament3 assigns A, B and C and initializes wins', () async {
      Session? savedSession;
      final dummySession = Session(id: 's1', playedAt: playedAt);
      final repo = _FakeTournamentRepository(dummySession, [])
        ..onSaveSession = (s) => savedSession = s;
      final container = containerFor(repo);

      await container.read(sessionsControllerProvider).createDraftSession(
        playedAt: playedAt,
        isRanked: true,
        sessionType: SessionType.tournament3,
        drawPoints: 2,
        allowUnevenTeams: false,
        playerTeamAssignments: {
          'p1': 'A',
          'p2': 'B',
          'p3': 'C',
        },
      );

      expect(savedSession, isNotNull);
      expect(savedSession!.sessionType, SessionType.tournament3);
      expect(savedSession!.drawPoints, 2);
      expect(savedSession!.scoreA, isNull);
      expect(savedSession!.scoreB, isNull);
      expect(savedSession!.winsA, 0);
      expect(savedSession!.winsB, 0);
      expect(savedSession!.winsC, 0);
      expect(savedSession!.result, isNull);
    });

    test('updateTournamentWins updates wins counter and result', () async {
      final tourn = Session(
        id: 's_tourn',
        playedAt: playedAt,
        sessionType: SessionType.tournament3,
      );
      final repo = _FakeTournamentRepository(tourn, []);
      final container = containerFor(repo);

      await container.read(sessionsControllerProvider).updateTournamentWins(
        sessionId: 's_tourn',
        winsA: 3,
        winsB: 2,
        winsC: 4,
        result: MatchResult.teamC,
      );

      expect(repo.session.winsA, 3);
      expect(repo.session.winsB, 2);
      expect(repo.session.winsC, 4);
      expect(repo.session.result, MatchResult.teamC);
    });

    test('closeSession closes a tournament session with a decided result', () async {
      final participants = [
        _part('p1', Team.a),
        _part('p2', Team.b),
        _part('p3', Team.c),
      ];
      final tourn = Session(
        id: 's_tourn',
        playedAt: playedAt,
        sessionType: SessionType.tournament3,
        winsA: 4,
        winsB: 2,
        winsC: 1,
        result: MatchResult.teamA,
      );
      final repo = _FakeTournamentRepository(tourn, participants);
      final container = containerFor(repo);

      final blockers = await container.read(sessionsControllerProvider).closeSession('s_tourn');

      expect(blockers, isEmpty);
      expect(repo.closeCalls, 1);
      expect(repo.session.status, SessionStatus.closed);
    });

    test('closeSession recomputes and synchronizes result when wins changed', () async {
      final participants = [
        _part('p1', Team.a),
        _part('p2', Team.b),
        _part('p3', Team.c),
      ];
      // Session has initial result teamA but wins were updated to Team B having more wins
      final tourn = Session(
        id: 's_tourn',
        playedAt: playedAt,
        sessionType: SessionType.tournament3,
        winsA: 1,
        winsB: 3,
        result: MatchResult.teamA, // Out of sync initially
      );
      final repo = _FakeTournamentRepository(tourn, participants);
      final container = containerFor(repo);

      final blockers = await container.read(sessionsControllerProvider).closeSession('s_tourn');

      expect(blockers, isEmpty);
      expect(repo.closeCalls, 1);
      expect(repo.session.result, MatchResult.teamB); // Recomputed to Team B!
      expect(repo.session.status, SessionStatus.closed);
    });
  });

  group('Tournament 3 Teams - computeTournamentResult', () {
    test('returns null when 0 wins are recorded for all 3 teams', () {
      expect(computeTournamentResult(0, 0, 0), isNull);
    });

    test('returns teamA when A has strictly more wins', () {
      expect(computeTournamentResult(3, 1, 1), MatchResult.teamA);
      expect(computeTournamentResult(1, 0, 0), MatchResult.teamA);
    });

    test('returns teamB when B has strictly more wins', () {
      expect(computeTournamentResult(1, 4, 2), MatchResult.teamB);
      expect(computeTournamentResult(0, 1, 0), MatchResult.teamB);
    });

    test('returns teamC when C has strictly more wins', () {
      expect(computeTournamentResult(2, 1, 5), MatchResult.teamC);
      expect(computeTournamentResult(0, 0, 1), MatchResult.teamC);
    });

    test('returns drawAB when A and B tie for the lead', () {
      expect(computeTournamentResult(3, 3, 1), MatchResult.drawAB);
      expect(computeTournamentResult(1, 1, 0), MatchResult.drawAB);
    });

    test('returns drawBC when B and C tie for the lead', () {
      expect(computeTournamentResult(0, 2, 2), MatchResult.drawBC);
      expect(computeTournamentResult(1, 3, 3), MatchResult.drawBC);
    });

    test('returns drawAC when A and C tie for the lead', () {
      expect(computeTournamentResult(2, 0, 2), MatchResult.drawAC);
      expect(computeTournamentResult(3, 1, 3), MatchResult.drawAC);
    });

    test('returns drawAll when all 3 teams tie with at least 1 win', () {
      expect(computeTournamentResult(1, 1, 1), MatchResult.drawAll);
      expect(computeTournamentResult(4, 4, 4), MatchResult.drawAll);
    });
  });
}
