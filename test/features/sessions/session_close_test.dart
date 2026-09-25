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

  @override
  Future<Session?> getSession(String id) async => id == session.id ? session : null;

  @override
  Future<List<SessionParticipantDetail>> getSessionParticipants(String sessionId) async => participants;

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

SessionParticipantDetail _participant(String id, Team team) => SessionParticipantDetail(
  participation: Participation(id: 'p_$id', sessionId: 's1', playerId: id, team: team),
  playerName: id,
);

final List<SessionParticipantDetail> _balancedTeams = [
  _participant('a1', Team.a),
  _participant('a2', Team.a),
  _participant('b1', Team.b),
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
      expect(closeBlockers(session: scored, teamACount: 6, teamBCount: 4), [CloseBlocker.unevenTeams]);
      expect(closeBlockers(session: scored, teamACount: 5, teamBCount: 4), isEmpty);
      expect(
        closeBlockers(session: scored.copyWith(allowUnevenTeams: true), teamACount: 6, teamBCount: 4),
        isEmpty,
      );
    });

    test('reports every blocker at once', () {
      expect(
        closeBlockers(session: unscored, teamACount: 7, teamBCount: 3),
        [CloseBlocker.missingScore, CloseBlocker.unevenTeams],
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
      final repo = _FakeSessionsRepository(scored, _balancedTeams);
      final blockers = await containerFor(repo).read(sessionsControllerProvider).closeSession('s1');

      expect(blockers, isEmpty);
      expect(repo.closeCalls, 1);
      expect(repo.session.status, SessionStatus.closed);
    });

    test('reports a refused write instead of claiming success', () async {
      final repo = _FakeSessionsRepository(scored, _balancedTeams)..closeSucceeds = false;
      final controller = containerFor(repo).read(sessionsControllerProvider);

      await expectLater(controller.closeSession('s1'), throwsA(isA<SessionCloseException>()));
      expect(repo.session.status, SessionStatus.draft);
    });
  });
}
