import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/app_database.dart';
import '../../ranking/application/ranking_providers.dart';
import '../../stats/application/stats_providers.dart';
import '../../team/application/team_provider.dart';
import '../data/sessions_repository.dart';
import '../domain/participation.dart';
import '../domain/session.dart';
import '../domain/session_close_rules.dart';
import '../domain/session_summary.dart';

final Provider<SessionsRepository> sessionsRepositoryProvider = Provider<SessionsRepository>((ref) {
  return SqliteSessionsRepository(AppDatabase.instance);
});

class SessionsFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  String get filter => state;
  set filter(String value) => state = value;

  void selectFilter(String value) {
    if (state != value) {
      state = value;
    }
  }
}

final NotifierProvider<SessionsFilterNotifier, String> sessionsFilterProvider =
    NotifierProvider<SessionsFilterNotifier, String>(SessionsFilterNotifier.new);

final FutureProvider<String?> activeSessionIdProvider = FutureProvider<String?>((ref) async {
  final teamId = ref.watch(activeTeamIdProvider);
  if (teamId == null) return null;
  return await ref.watch(sessionsRepositoryProvider).getActiveSessionId(teamId: teamId);
});

final FutureProvider<List<SessionSummaryItem>> allSessionsProvider =
    FutureProvider<List<SessionSummaryItem>>((ref) async {
  final teamId = ref.watch(activeTeamIdProvider);
  if (teamId == null) return [];
  return await ref.watch(sessionsRepositoryProvider).getSessionSummaries(teamId: teamId);
});

final FutureProvider<List<SessionSummaryItem>> sessionsListProvider =
    FutureProvider<List<SessionSummaryItem>>((ref) async {
  final allSessions = await ref.watch(allSessionsProvider.future);
  final filter = ref.watch(sessionsFilterProvider);
  return switch (filter) {
    'ranked' => allSessions.where((s) => s.isRanked).toList(),
    'friendly' => allSessions.where((s) => !s.isRanked).toList(),
    'draft' => allSessions.where((s) => s.isDraft).toList(),
    _ => allSessions,
  };
});

final FutureProvider<Session?> activeDraftSessionProvider = FutureProvider<Session?>((ref) async {
  final teamId = ref.watch(activeTeamIdProvider);
  if (teamId == null) return null;
  return await ref.watch(sessionsRepositoryProvider).getActiveDraftSession(teamId: teamId);
});

// Inferred Riverpod provider family type.
// ignore: specify_nonobvious_property_types
final sessionDetailProvider = FutureProvider.family<Session?, String>((ref, id) {
  return ref.watch(sessionsRepositoryProvider).getSession(id);
});

// Inferred Riverpod provider family type.
// ignore: specify_nonobvious_property_types
final sessionParticipantsProvider =
    FutureProvider.family<List<SessionParticipantDetail>, String>((ref, sessionId) {
  return ref.watch(sessionsRepositoryProvider).getSessionParticipants(sessionId);
});

class SessionsController {
  SessionsController(this._ref);

  final Ref _ref;

  SessionsRepository get _repo => _ref.read(sessionsRepositoryProvider);

  void _invalidateAll([String? sessionId]) {
    _ref
      ..invalidate(allSessionsProvider)
      ..invalidate(sessionsListProvider)
      ..invalidate(activeSessionIdProvider)
      ..invalidate(activeDraftSessionProvider)
      ..invalidate(standingsProvider)
      ..invalidate(standingsPerMatchProvider)
      ..invalidate(topScorersProvider)
      ..invalidate(topAssistsProvider)
      ..invalidate(topCardsProvider)
      ..invalidate(groupTotalsProvider);

    if (sessionId != null) {
      _ref
        ..invalidate(sessionDetailProvider(sessionId))
        ..invalidate(sessionParticipantsProvider(sessionId));
    }
  }

  Future<String> createDraftSession({
    required DateTime playedAt,
    required bool isRanked,
    required bool allowUnevenTeams,
    required Map<String, String> playerTeamAssignments,
    SessionType sessionType = SessionType.classic2,
    int drawPoints = 1,
    bool startImmediately = true,
  }) async {
    final teamId = _ref.read(activeTeamIdProvider);
    if (teamId == null) throw StateError('No active team selected');

    final isTournament = sessionType == SessionType.tournament3;
    final sessionId = 's_${DateTime.now().millisecondsSinceEpoch}';
    final session = Session(
      id: sessionId,
      playedAt: playedAt,
      isRanked: isRanked,
      sessionType: sessionType,
      allowUnevenTeams: allowUnevenTeams,
      scoreA: isTournament ? null : 0,
      scoreB: isTournament ? null : 0,
      drawPoints: drawPoints,
      result: isTournament ? null : MatchResult.draw,
    );

    final participations = playerTeamAssignments.entries.map((e) {
      final partId = 'p_${sessionId}_${e.key}';
      final Team team;
      if (e.value == 'C') {
        team = Team.c;
      } else if (e.value == 'B') {
        team = Team.b;
      } else {
        team = Team.a;
      }
      return Participation(
        id: partId,
        sessionId: sessionId,
        playerId: e.key,
        team: team,
      );
    }).toList();

    await _repo.saveSession(session, participations, teamId: teamId);

    // If starting immediately and no session is already active, activate it
    final currentActiveId = await _repo.getActiveSessionId(teamId: teamId);
    if (startImmediately && currentActiveId == null) {
      await _repo.setActiveSessionId(sessionId, teamId: teamId);
    }

    _invalidateAll(sessionId);
    return sessionId;
  }

  Future<bool> startSession(String sessionId) async {
    final teamId = _ref.read(activeTeamIdProvider);
    if (teamId == null) return false;

    final currentActiveId = await _repo.getActiveSessionId(teamId: teamId);
    if (currentActiveId != null && currentActiveId != sessionId) {
      return false; // Another session is already running
    }
    final session = await _repo.getSession(sessionId);
    if (session != null &&
        session.sessionType == SessionType.classic2 &&
        (session.scoreA == null || session.scoreB == null || session.result == null)) {
      await _repo.updateSessionScore(sessionId: sessionId, scoreA: 0, scoreB: 0);
    }
    await _repo.setActiveSessionId(sessionId, teamId: teamId);
    _invalidateAll(sessionId);
    return true;
  }

  Future<void> updateScore({
    required String sessionId,
    required int scoreA,
    required int scoreB,
  }) async {
    await _repo.updateSessionScore(
      sessionId: sessionId,
      scoreA: scoreA,
      scoreB: scoreB,
    );
    _invalidateAll(sessionId);
  }

  Future<void> updateTournamentWins({
    required String sessionId,
    required int winsA,
    required int winsB,
    required int winsC,
    MatchResult? result,
  }) async {
    await _repo.updateTournamentWins(
      sessionId: sessionId,
      winsA: winsA,
      winsB: winsB,
      winsC: winsC,
      result: result,
    );
    _invalidateAll(sessionId);
  }

  Future<void> updateParticipationStats({
    required String sessionId,
    required String participationId,
    required int goals,
    required int assists,
    required int yellowCards,
    required int redCards,
  }) async {
    await _repo.updateParticipationStats(
      participationId: participationId,
      goals: goals,
      assists: assists,
      yellowCards: yellowCards,
      redCards: redCards,
    );
    _invalidateAll(sessionId);
  }

  Future<void> addLatePlayers({
    required String sessionId,
    required Map<String, Team> playerTeamAssignments,
  }) async {
    final teamId = _ref.read(activeTeamIdProvider);
    if (teamId == null) throw StateError('No active team selected');

    if (playerTeamAssignments.isEmpty) return;

    final participations = playerTeamAssignments.entries.map((e) {
      final partId = 'p_${sessionId}_${e.key}';
      return Participation(
        id: partId,
        sessionId: sessionId,
        playerId: e.key,
        team: e.value,
      );
    }).toList();

    await _repo.addParticipations(
      sessionId: sessionId,
      participations: participations,
    );
    _invalidateAll(sessionId);
  }

  /// Closes the session if no blocking rule applies. Returns the blockers found
  /// (empty when closed), re-checked on fresh data rather than on what the screen showed.
  Future<List<CloseBlocker>> closeSession(String sessionId) async {
    final teamId = _ref.read(activeTeamIdProvider);
    if (teamId == null) throw StateError('No active team selected');

    final session = await _repo.getSession(sessionId);
    if (session == null) throw SessionCloseException('Session $sessionId not found');
    final participants = await _repo.getSessionParticipants(sessionId);

    final blockers = closeBlockers(
      session: session,
      teamACount: participants.where((p) => p.participation.team == Team.a).length,
      teamBCount: participants.where((p) => p.participation.team == Team.b).length,
      teamCCount: participants.where((p) => p.participation.team == Team.c).length,
    );
    if (blockers.isNotEmpty) return blockers;

    final closed = await _repo.closeSession(sessionId, teamId: teamId);
    if (!closed) throw SessionCloseException('Session $sessionId could not be closed');
    _invalidateAll(sessionId);
    return const [];
  }

  Future<void> reopenSession(String sessionId) async {
    await _repo.reopenSession(sessionId);
    _invalidateAll(sessionId);
  }

  Future<void> deleteSession(String sessionId) async {
    final teamId = _ref.read(activeTeamIdProvider);
    if (teamId == null) return;
    await _repo.deleteSession(sessionId, teamId: teamId);
    _invalidateAll(sessionId);
  }
}

final Provider<SessionsController> sessionsControllerProvider = Provider<SessionsController>((ref) {
  return SessionsController(ref);
});
