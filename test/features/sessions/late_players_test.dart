import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/data/sessions_repository.dart';
import 'package:statoo/features/sessions/domain/participation.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/domain/session_summary.dart';
import 'package:statoo/features/team/application/team_provider.dart';

class _FakeSessionsRepository implements SessionsRepository {
  _FakeSessionsRepository(this.session, this.participants);

  Session session;
  final List<SessionParticipantDetail> participants;
  final List<Participation> addedParticipations = [];

  @override
  Future<Session?> getSession(String id) async => id == session.id ? session : null;

  @override
  Future<List<SessionParticipantDetail>> getSessionParticipants(String sessionId) async => [
        ...participants,
        ...addedParticipations.map(
          (p) => SessionParticipantDetail(
            participation: p,
            playerName: 'Player ${p.playerId}',
          ),
        ),
      ];

  @override
  Future<void> addParticipations({
    required String sessionId,
    required List<Participation> participations,
  }) async {
    addedParticipations.addAll(participations);
  }

  @override
  Future<bool> closeSession(String sessionId, {required String teamId}) async {
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

void main() {
  final playedAt = DateTime(2026, 9, 25, 20, 30);
  final session = Session(id: 's1', playedAt: playedAt, isRanked: true, scoreA: 5, scoreB: 4, result: MatchResult.teamA);

  group('SessionsController.addLatePlayers', () {
    ProviderContainer containerFor(SessionsRepository repo, {String? teamId = 't1'}) {
      final container = ProviderContainer(
        overrides: [
          sessionsRepositoryProvider.overrideWithValue(repo),
          activeTeamIdProvider.overrideWith(() => ActiveTeamIdNotifier(initialValue: teamId)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('throws StateError when no active team is selected', () async {
      final repo = _FakeSessionsRepository(session, []);
      final container = containerFor(repo, teamId: null);

      expect(
        () => container.read(sessionsControllerProvider).addLatePlayers(
          sessionId: 's1',
          playerTeamAssignments: {'player1': Team.a},
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('adds late-arriving players to the session with correct teams', () async {
      final initialParticipants = [
        _participant('a1', Team.a),
        _participant('a2', Team.a),
        _participant('b1', Team.b),
        _participant('b2', Team.b),
      ];
      final repo = _FakeSessionsRepository(session, initialParticipants);
      final container = containerFor(repo);

      await container.read(sessionsControllerProvider).addLatePlayers(
        sessionId: 's1',
        playerTeamAssignments: {
          'late_a': Team.a,
          'late_b': Team.b,
        },
      );

      expect(repo.addedParticipations.length, 2);
      expect(repo.addedParticipations.any((p) => p.playerId == 'late_a' && p.team == Team.a), isTrue);
      expect(repo.addedParticipations.any((p) => p.playerId == 'late_b' && p.team == Team.b), isTrue);
    });

    test('allows teams with more than 5 players (substitutes) and closes without error', () async {
      // 5v5 initially
      final fiveVsFive = [
        _participant('a1', Team.a),
        _participant('a2', Team.a),
        _participant('a3', Team.a),
        _participant('a4', Team.a),
        _participant('a5', Team.a),
        _participant('b1', Team.b),
        _participant('b2', Team.b),
        _participant('b3', Team.b),
        _participant('b4', Team.b),
        _participant('b5', Team.b),
      ];
      final repo = _FakeSessionsRepository(session, fiveVsFive);
      final container = containerFor(repo);

      // Add 2 late players -> 6 vs 6
      await container.read(sessionsControllerProvider).addLatePlayers(
        sessionId: 's1',
        playerTeamAssignments: {
          'a6': Team.a,
          'b6': Team.b,
        },
      );

      // Verify close blockers with 6v6: should be empty
      final blockers = await container.read(sessionsControllerProvider).closeSession('s1');
      expect(blockers, isEmpty);
      expect(repo.session.status, SessionStatus.closed);
    });

    test('throws StateError when adding late players would unbalance teams by > 1 player', () async {
      final fiveVsFive = [
        _participant('a1', Team.a),
        _participant('a2', Team.a),
        _participant('a3', Team.a),
        _participant('a4', Team.a),
        _participant('a5', Team.a),
        _participant('b1', Team.b),
        _participant('b2', Team.b),
        _participant('b3', Team.b),
        _participant('b4', Team.b),
        _participant('b5', Team.b),
      ];
      final repo = _FakeSessionsRepository(session, fiveVsFive);
      final container = containerFor(repo);

      expect(
        () => container.read(sessionsControllerProvider).addLatePlayers(
          sessionId: 's1',
          playerTeamAssignments: {
            'a6': Team.a,
            'a7': Team.a,
          },
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
