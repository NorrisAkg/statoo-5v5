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
final sessionDetailProvider = FutureProvider.autoDispose.family<Session?, String>((ref, id) {
  return ref.watch(sessionsRepositoryProvider).getSession(id);
});

// Inferred Riverpod provider family type.
// ignore: specify_nonobvious_property_types
final sessionParticipantsProvider =
    FutureProvider.autoDispose.family<List<SessionParticipantDetail>, String>((ref, sessionId) {
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
    bool startImmediately = true,
  }) async {
    final teamId = _ref.read(activeTeamIdProvider);
    if (teamId == null) throw StateError('No active team selected');

    final sessionId = 's_${DateTime.now().millisecondsSinceEpoch}';
    final session = Session(
      id: sessionId,
      playedAt: playedAt,
      isRanked: isRanked,
      allowUnevenTeams: allowUnevenTeams,
      // TODO(cdc): Initialisation à 0-0 par défaut (choix produit ebadbc7).
      // Un dialogue de clôture avec récapitulatif et alerte explicite protège contre les clôtures sans score.
      scoreA: 0,
      scoreB: 0,
      result: MatchResult.draw,
    );

    final participations = playerTeamAssignments.entries.map((e) {
      final partId = 'p_${sessionId}_${e.key}';
      return Participation(
        id: partId,
        sessionId: sessionId,
        playerId: e.key,
        team: e.value == 'B' ? Team.b : Team.a,
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

    final session = await _repo.getSession(sessionId);
    if (session == null) throw StateError('Session $sessionId not found');
    final participants = await _repo.getSessionParticipants(sessionId);

    final currentA = participants.where((p) => p.participation.team == Team.a).length;
    final currentB = participants.where((p) => p.participation.team == Team.b).length;
    final addingA = playerTeamAssignments.values.where((t) => t == Team.a).length;
    final addingB = playerTeamAssignments.values.where((t) => t == Team.b).length;
    final totalA = currentA + addingA;
    final totalB = currentB + addingB;

    if (!session.allowUnevenTeams && (totalA - totalB).abs() > 1) {
      throw StateError(
        "L'écart d'effectif dépasserait 1 joueur ($totalA vs $totalB) sans l'option équipes inégales.",
      );
    }

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
