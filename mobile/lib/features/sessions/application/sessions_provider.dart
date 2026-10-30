import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/app_database.dart';
import '../../../core/data/occurrence_registry.dart';
import '../../finance/application/finance_providers.dart';
import '../../players/application/players_provider.dart';
import '../../ranking/application/ranking_providers.dart';
import '../../shared/application/shared_providers.dart';
import '../../stats/application/stats_providers.dart';
import '../../team/application/team_provider.dart';
import '../data/live_stats_repository.dart';
import '../data/sessions_repository.dart';
import '../domain/participation.dart';
import '../domain/session.dart';
import '../domain/session_close_rules.dart';
import '../domain/session_summary.dart';
import '../domain/team_appearance.dart';

final Provider<SessionsRepository> sessionsRepositoryProvider =
    Provider<SessionsRepository>((ref) {
      return SqliteSessionsRepository(AppDatabase.instance);
    });

final Provider<LiveStatsRepository> liveStatsRepositoryProvider = Provider(
  (ref) => LiveStatsRepository(ref.watch(sharedServiceProvider).database),
);
// Riverpod infers the auto-disposed family type, as for sessionDetailProvider.
// ignore: specify_nonobvious_property_types
final liveJournalProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) {
      final group = ref.watch(activeTeamIdProvider);
      if (group == null) return [];
      return ref.watch(liveStatsRepositoryProvider).journal(group, id);
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
    NotifierProvider<SessionsFilterNotifier, String>(
      SessionsFilterNotifier.new,
    );

final FutureProvider<String?> activeSessionIdProvider = FutureProvider<String?>(
  (ref) async {
    final teamId = ref.watch(activeTeamIdProvider);
    if (teamId == null) return null;
    return await ref
        .watch(sessionsRepositoryProvider)
        .getActiveSessionId(teamId: teamId);
  },
);

final FutureProvider<List<SessionSummaryItem>> allSessionsProvider =
    FutureProvider<List<SessionSummaryItem>>((ref) async {
      final teamId = ref.watch(activeTeamIdProvider);
      if (teamId == null) return [];
      return await ref
          .watch(sessionsRepositoryProvider)
          .getSessionSummaries(teamId: teamId);
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

final FutureProvider<Session?> activeDraftSessionProvider =
    FutureProvider<Session?>((ref) async {
      final teamId = ref.watch(activeTeamIdProvider);
      if (teamId == null) return null;
      return await ref
          .watch(sessionsRepositoryProvider)
          .getActiveDraftSession(teamId: teamId);
    });

// Inferred Riverpod provider family type.
// ignore: specify_nonobvious_property_types
final nextSessionReferenceProvider = FutureProvider.autoDispose
    .family<String, DateTime>((ref, date) async {
      final teamId = ref.watch(activeTeamIdProvider);
      if (teamId == null) return '';
      final db = await ref.watch(sharedServiceProvider).database.database;
      return await nextFreeOccurrenceReference(db, teamId, date);
    });

// Inferred Riverpod provider family type.
// ignore: specify_nonobvious_property_types
final sessionDetailProvider = FutureProvider.autoDispose
    .family<Session?, String>((ref, id) {
      final teamId = ref.watch(activeTeamIdProvider);
      if (teamId == null) return null;
      return ref
          .watch(sessionsRepositoryProvider)
          .getSession(id, teamId: teamId);
    });

// Inferred Riverpod provider family type.
// ignore: specify_nonobvious_property_types
final sessionParticipantsProvider = FutureProvider.autoDispose
    .family<List<SessionParticipantDetail>, String>((ref, sessionId) {
      final teamId = ref.watch(activeTeamIdProvider);
      if (teamId == null) return const <SessionParticipantDetail>[];
      return ref
          .watch(sessionsRepositoryProvider)
          .getSessionParticipants(sessionId, teamId: teamId);
    });

class SessionsController {
  SessionsController(this._ref);

  final Ref _ref;

  SessionsRepository get _repo => _ref.read(sessionsRepositoryProvider);

  Future<void> recordLive(
    String id,
    Map<String, dynamic>? action, {
    String? edit,
  }) async {
    final group = _ref.read(activeTeamIdProvider);
    if (group == null) throw StateError('Aucun groupe sélectionné.');
    final shared = _ref.read(sharedServiceProvider);
    await shared.requireWrite(group, 'sport', sessionId: id);
    final live = _ref.read(liveStatsRepositoryProvider);
    if (action == null) {
      await live.undo(group, id);
    } else {
      await live.apply(group, id, action, edit: edit);
    }
    _invalidateAll(id);
    _ref.invalidate(liveJournalProvider(id));
    try {
      await shared.queueSport(group, id);
    } on Object {
      throw StateError(
        'Action conservée localement. Synchronisation indisponible ; réessayez depuis le groupe partagé.',
      );
    }
  }

  void _invalidateAll([String? sessionId]) {
    final teamId = _ref.read(activeTeamIdProvider);
    _ref
      ..invalidate(financialPointsProvider)
      ..invalidate(financialTotalsProvider)
      ..invalidate(allSessionsProvider)
      ..invalidate(sessionsListProvider)
      ..invalidate(activeSessionIdProvider)
      ..invalidate(activeDraftSessionProvider)
      ..invalidate(standingsProvider)
      ..invalidate(standingsPerMatchProvider)
      ..invalidate(topScorersProvider)
      ..invalidate(topAssistsProvider)
      ..invalidate(topCardsProvider)
      ..invalidate(availableRankingMonthsProvider)
      ..invalidate(monthlyMvpRankingProvider)
      ..invalidate(playerOfTheMonthProvider)
      ..invalidate(groupTotalsProvider)
      ..invalidate(playersListProvider)
      ..invalidate(deletablePlayerIdsProvider)
      ..invalidate(nextSessionReferenceProvider);

    if (teamId != null) {
      _ref.invalidate(teamCountsProvider(teamId));
    }

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
    Map<String, String> teamNames = const {},
    Map<String, int> teamColors = const {},
    String? occurrenceId,
  }) async {
    final teamId = _ref.read(activeTeamIdProvider);
    if (teamId == null) throw StateError('No active team selected');
    await _ref.read(sharedServiceProvider).requireWrite(teamId, 'sport');

    final appearanceError = teamAppearanceError(
      sessionType,
      teamNames,
      teamColors,
    );
    if (appearanceError != null) throw ArgumentError(appearanceError);
    final isTournament = sessionType == SessionType.tournament3;
    final sessionId = 's_${_ref.read(sharedServiceProvider).operationId()}';
    final session = Session(
      id: sessionId,
      playedAt: playedAt,
      isRanked: isRanked,
      sessionType: sessionType,
      allowUnevenTeams: allowUnevenTeams,
      // TODO(cdc): Pour le mode classique 2 équipes, initialisation à 0-0 par défaut (choix produit ebadbc7).
      // Pour le tournoi 3 équipes, les scores de match ne sont pas initialisés et les victoires font foi.
      scoreA: isTournament ? null : 0,
      scoreB: isTournament ? null : 0,
      drawPoints: drawPoints,
      teamNames: {
        for (final entry in teamNames.entries)
          if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
      },
      teamColors: teamColors,
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

    if (occurrenceId != null && occurrenceId.trim().isNotEmpty) {
      final db = await _ref.read(sharedServiceProvider).database.database;
      await db.insert('meta', {
        'key': 'shared_occurrence_$sessionId',
        'value': occurrenceId.trim(),
      });
    }
    await _repo.saveSession(session, participations, teamId: teamId);

    // If starting immediately and no session is already active, activate it
    final currentActiveId = await _repo.getActiveSessionId(teamId: teamId);
    if (startImmediately && currentActiveId == null) {
      await _repo.setActiveSessionId(sessionId, teamId: teamId);
    }

    if (startImmediately && currentActiveId == null) {
      await _ref.read(sharedServiceProvider).queueSport(teamId, sessionId);
    }
    _invalidateAll(sessionId);
    return sessionId;
  }

  Future<bool> startSession(String sessionId) async {
    final teamId = _ref.read(activeTeamIdProvider);
    if (teamId == null) return false;
    await _ref
        .read(sharedServiceProvider)
        .requireWrite(teamId, 'sport', sessionId: sessionId);

    final currentActiveId = await _repo.getActiveSessionId(teamId: teamId);
    if (currentActiveId != null && currentActiveId != sessionId) {
      return false; // Another session is already running
    }
    final session = await _repo.getSession(sessionId, teamId: teamId);
    if (session == null) return false;
    if (session.sessionType == SessionType.classic2 &&
        (session.scoreA == null ||
            session.scoreB == null ||
            session.result == null)) {
      await _repo.updateSessionScore(
        sessionId: sessionId,
        teamId: teamId,
        scoreA: 0,
        scoreB: 0,
      );
    }
    await _repo.setActiveSessionId(sessionId, teamId: teamId);
    await _ref.read(sharedServiceProvider).queueSport(teamId, sessionId);
    _invalidateAll(sessionId);
    return true;
  }

  Future<void> updateScore({
    required String sessionId,
    required int scoreA,
    required int scoreB,
  }) async {
    final teamId = _ref.read(activeTeamIdProvider);
    if (teamId == null) throw StateError('No active team selected');
    await _ref
        .read(sharedServiceProvider)
        .requireWrite(teamId, 'sport', sessionId: sessionId);
    await _repo.updateSessionScore(
      sessionId: sessionId,
      teamId: teamId,
      scoreA: scoreA,
      scoreB: scoreB,
    );
    await _ref.read(sharedServiceProvider).queueSport(teamId, sessionId);
    _invalidateAll(sessionId);
  }

  Future<void> incrementScore({
    required String sessionId,
    required Team team,
    required int delta,
  }) async {
    final teamId = _ref.read(activeTeamIdProvider);
    if (teamId == null) throw StateError('No active team selected');
    await _ref
        .read(sharedServiceProvider)
        .requireWrite(teamId, 'sport', sessionId: sessionId);
    await _repo.incrementScore(
      sessionId: sessionId,
      teamId: teamId,
      team: team,
      delta: delta,
    );
    await _ref.read(sharedServiceProvider).queueSport(teamId, sessionId);
    _invalidateAll(sessionId);
  }

  Future<void> updateTournamentWins({
    required String sessionId,
    required int winsA,
    required int winsB,
    required int winsC,
    MatchResult? result,
  }) async {
    final teamId = _ref.read(activeTeamIdProvider);
    if (teamId == null) throw StateError('No active team selected');
    await _ref
        .read(sharedServiceProvider)
        .requireWrite(teamId, 'sport', sessionId: sessionId);
    await _repo.updateTournamentWins(
      sessionId: sessionId,
      teamId: teamId,
      winsA: winsA,
      winsB: winsB,
      winsC: winsC,
      result: result,
    );
    await _ref.read(sharedServiceProvider).queueSport(teamId, sessionId);
    _invalidateAll(sessionId);
  }

  Future<void> updateUnassignedGoals({
    required String sessionId,
    int? unassignedGoalsA,
    int? unassignedGoalsB,
    int? unassignedGoalsC,
  }) async {
    final teamId = _ref.read(activeTeamIdProvider);
    if (teamId == null) throw StateError('No active team selected');
    await _ref
        .read(sharedServiceProvider)
        .requireWrite(teamId, 'sport', sessionId: sessionId);
    // The repository keeps the team score in sync in the same transaction.
    await _repo.updateUnassignedGoals(
      sessionId: sessionId,
      teamId: teamId,
      unassignedGoalsA: unassignedGoalsA,
      unassignedGoalsB: unassignedGoalsB,
      unassignedGoalsC: unassignedGoalsC,
    );
    await _ref.read(sharedServiceProvider).queueSport(teamId, sessionId);
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
    final teamId = _ref.read(activeTeamIdProvider);
    if (teamId == null) throw StateError('No active team selected');
    await _ref
        .read(sharedServiceProvider)
        .requireWrite(teamId, 'sport', sessionId: sessionId);

    await _repo.updateParticipationStats(
      participationId: participationId,
      sessionId: sessionId,
      teamId: teamId,
      goals: goals,
      assists: assists,
      yellowCards: yellowCards,
      redCards: redCards,
    );
    await _ref.read(sharedServiceProvider).queueSport(teamId, sessionId);
    _invalidateAll(sessionId);
  }

  Future<void> addLatePlayers({
    required String sessionId,
    required Map<String, Team> playerTeamAssignments,
  }) async {
    final teamId = _ref.read(activeTeamIdProvider);
    if (teamId == null) throw StateError('No active team selected');
    await _ref
        .read(sharedServiceProvider)
        .requireWrite(teamId, 'sport', sessionId: sessionId);

    if (playerTeamAssignments.isEmpty) return;

    final session = await _repo.getSession(sessionId, teamId: teamId);
    if (session == null) throw StateError('Session $sessionId not found');
    final participants = await _repo.getSessionParticipants(
      sessionId,
      teamId: teamId,
    );

    final currentA = participants
        .where((p) => p.participation.team == Team.a)
        .length;
    final currentB = participants
        .where((p) => p.participation.team == Team.b)
        .length;
    final currentC = participants
        .where((p) => p.participation.team == Team.c)
        .length;
    final addingA = playerTeamAssignments.values
        .where((t) => t == Team.a)
        .length;
    final addingB = playerTeamAssignments.values
        .where((t) => t == Team.b)
        .length;
    final addingC = playerTeamAssignments.values
        .where((t) => t == Team.c)
        .length;
    final totalA = currentA + addingA;
    final totalB = currentB + addingB;
    final totalC = currentC + addingC;

    if (!session.allowUnevenTeams) {
      if (session.sessionType == SessionType.tournament3) {
        final counts = [totalA, totalB, totalC];
        final maxCount = counts.reduce((a, b) => a > b ? a : b);
        final minCount = counts.reduce((a, b) => a < b ? a : b);
        if (maxCount - minCount > 1) {
          throw StateError(
            "L'écart d'effectif dépasserait 1 joueur ($totalA vs $totalB vs $totalC) sans l'option équipes inégales.",
          );
        }
      } else {
        if ((totalA - totalB).abs() > 1) {
          throw StateError(
            "L'écart d'effectif dépasserait 1 joueur ($totalA vs $totalB) sans l'option équipes inégales.",
          );
        }
      }
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
      teamId: teamId,
      participations: participations,
    );
    await _ref.read(sharedServiceProvider).queueSport(teamId, sessionId);
    _invalidateAll(sessionId);
  }

  List<CloseBlocker> _evaluateCloseBlockers(
    Session session,
    List<SessionParticipantDetail> participants,
  ) {
    final isTournament = session.sessionType == SessionType.tournament3;
    final effectiveResult = isTournament
        ? (computeTournamentResult(
              session.winsA,
              session.winsB,
              session.winsC,
            ) ??
            session.result)
        : session.result;
    final effectiveSession = session.copyWith(result: effectiveResult);

    final teamAParts = participants.where(
      (p) => p.participation.team == Team.a,
    );
    final teamBParts = participants.where(
      (p) => p.participation.team == Team.b,
    );
    final teamCParts = participants.where(
      (p) => p.participation.team == Team.c,
    );

    return closeBlockers(
      session: effectiveSession,
      teamACount: teamAParts.length,
      teamBCount: teamBParts.length,
      teamCCount: isTournament ? teamCParts.length : null,
      playerGoalsA: teamAParts.fold<int>(
        0,
        (s, p) => s + p.participation.goals,
      ),
      playerGoalsB: teamBParts.fold<int>(
        0,
        (s, p) => s + p.participation.goals,
      ),
      playerGoalsC: teamCParts.fold<int>(
        0,
        (s, p) => s + p.participation.goals,
      ),
      playerAssistsA: teamAParts.fold<int>(
        0,
        (s, p) => s + p.participation.assists,
      ),
      playerAssistsB: teamBParts.fold<int>(
        0,
        (s, p) => s + p.participation.assists,
      ),
      playerAssistsC: teamCParts.fold<int>(
        0,
        (s, p) => s + p.participation.assists,
      ),
      participations: participants.map((p) => p.participation),
    );
  }

  /// Closes the session if no blocking rule applies. Returns the blockers found
  /// (empty when closed), re-checked on fresh data rather than on what the screen showed.
  Future<List<CloseBlocker>> closeSession(String sessionId) async {
    final teamId = _ref.read(activeTeamIdProvider);
    if (teamId == null) throw StateError('No active team selected');
    await _ref
        .read(sharedServiceProvider)
        .requireWrite(teamId, 'sport', sessionId: sessionId);

    final session = await _repo.getSession(sessionId, teamId: teamId);
    if (session == null || session.status != SessionStatus.draft) {
      throw SessionCloseException('Session $sessionId not found or not in DRAFT');
    }
    final participants = await _repo.getSessionParticipants(
      sessionId,
      teamId: teamId,
    );

    final blockers = _evaluateCloseBlockers(session, participants);
    if (blockers.isNotEmpty) return blockers;

    // SqliteSessionsRepository computes and persists the tournament result
    // atomically inside closeSession's single SQLite transaction.
    if (_repo is! SqliteSessionsRepository &&
        session.sessionType == SessionType.tournament3) {
      final tournamentResult = computeTournamentResult(
        session.winsA,
        session.winsB,
        session.winsC,
      );
      if (tournamentResult != null && tournamentResult != session.result) {
        await _repo.updateTournamentWins(
          sessionId: sessionId,
          teamId: teamId,
          winsA: session.winsA,
          winsB: session.winsB,
          winsC: session.winsC,
          result: tournamentResult,
        );
      }
    }

    final closed = await _repo.closeSession(sessionId, teamId: teamId);
    if (!closed) {
      final freshSession = await _repo.getSession(sessionId, teamId: teamId);
      if (freshSession != null && freshSession.status == SessionStatus.draft) {
        final freshParticipants = await _repo.getSessionParticipants(
          sessionId,
          teamId: teamId,
        );
        final freshBlockers = _evaluateCloseBlockers(
          freshSession,
          freshParticipants,
        );
        if (freshBlockers.isNotEmpty) return freshBlockers;
      }
      throw SessionCloseException('Session $sessionId could not be closed');
    }
    await _ref.read(sharedServiceProvider).queueSport(teamId, sessionId);
    _invalidateAll(sessionId);
    return const [];
  }

  Future<void> switchPlayerTeam({
    required String sessionId,
    required String participationId,
    required Team currentTeam,
    Team? targetTeam,
  }) async {
    final teamId = _ref.read(activeTeamIdProvider);
    if (teamId == null) throw StateError('No active team selected');
    await _ref
        .read(sharedServiceProvider)
        .requireWrite(teamId, 'sport', sessionId: sessionId);

    final session = await _repo.getSession(sessionId, teamId: teamId);
    if (session == null) throw StateError('Session $sessionId not found');
    final participants = await _repo.getSessionParticipants(
      sessionId,
      teamId: teamId,
    );

    final currentA = participants
        .where((p) => p.participation.team == Team.a)
        .length;
    final currentB = participants
        .where((p) => p.participation.team == Team.b)
        .length;
    final currentC = participants
        .where((p) => p.participation.team == Team.c)
        .length;
    final isTournament = session.sessionType == SessionType.tournament3;

    final newTeam =
        targetTeam ??
        (isTournament
            ? (currentTeam == Team.a
                  ? Team.b
                  : (currentTeam == Team.b ? Team.c : Team.a))
            : (currentTeam == Team.a ? Team.b : Team.a));

    final nextA = newTeam == Team.a
        ? (currentTeam == Team.a ? currentA : currentA + 1)
        : (currentTeam == Team.a ? currentA - 1 : currentA);
    final nextB = newTeam == Team.b
        ? (currentTeam == Team.b ? currentB : currentB + 1)
        : (currentTeam == Team.b ? currentB - 1 : currentB);
    final nextC = newTeam == Team.c
        ? (currentTeam == Team.c ? currentC : currentC + 1)
        : (currentTeam == Team.c ? currentC - 1 : currentC);

    if (!session.allowUnevenTeams) {
      if (isTournament) {
        final counts = [nextA, nextB, nextC];
        final maxCount = counts.reduce((a, b) => a > b ? a : b);
        final minCount = counts.reduce((a, b) => a < b ? a : b);
        if (maxCount - minCount > 1) {
          throw StateError(
            "Ce changement créerait un écart d'effectif de ${maxCount - minCount} joueurs sans l'option équipes inégales.",
          );
        }
      } else {
        if ((nextA - nextB).abs() > 1) {
          throw StateError(
            "Ce changement créerait un écart d'effectif de ${(nextA - nextB).abs()} joueurs ($nextA vs $nextB) sans l'option équipes inégales.",
          );
        }
      }
    }

    await _repo.switchPlayerTeam(
      sessionId: sessionId,
      participationId: participationId,
      newTeam: newTeam,
      teamId: teamId,
    );
    await _ref.read(sharedServiceProvider).queueSport(teamId, sessionId);
    _invalidateAll(sessionId);
  }

  Future<void> removeParticipation({
    required String sessionId,
    required String participationId,
    required Team playerTeam,
  }) async {
    final teamId = _ref.read(activeTeamIdProvider);
    if (teamId == null) throw StateError('No active team selected');
    await _ref
        .read(sharedServiceProvider)
        .requireWrite(teamId, 'sport', sessionId: sessionId);

    final session = await _repo.getSession(sessionId, teamId: teamId);
    if (session == null) throw StateError('Session $sessionId not found');
    final participants = await _repo.getSessionParticipants(
      sessionId,
      teamId: teamId,
    );

    final currentA = participants
        .where((p) => p.participation.team == Team.a)
        .length;
    final currentB = participants
        .where((p) => p.participation.team == Team.b)
        .length;
    final currentC = participants
        .where((p) => p.participation.team == Team.c)
        .length;
    final isTournament = session.sessionType == SessionType.tournament3;

    final nextA = playerTeam == Team.a ? currentA - 1 : currentA;
    final nextB = playerTeam == Team.b ? currentB - 1 : currentB;
    final nextC = playerTeam == Team.c ? currentC - 1 : currentC;

    if (!session.allowUnevenTeams) {
      if (isTournament) {
        final counts = [nextA, nextB, nextC];
        final maxCount = counts.reduce((a, b) => a > b ? a : b);
        final minCount = counts.reduce((a, b) => a < b ? a : b);
        if (maxCount - minCount > 1) {
          throw StateError(
            "Ce retrait créerait un écart d'effectif de ${maxCount - minCount} joueurs sans l'option équipes inégales.",
          );
        }
      } else {
        if ((nextA - nextB).abs() > 1) {
          throw StateError(
            "Ce retrait créerait un écart d'effectif de ${(nextA - nextB).abs()} joueurs ($nextA vs $nextB) sans l'option équipes inégales.",
          );
        }
      }
    }

    await _repo.removeParticipation(
      sessionId: sessionId,
      participationId: participationId,
      teamId: teamId,
    );
    await _ref.read(sharedServiceProvider).queueSport(teamId, sessionId);
    _invalidateAll(sessionId);
  }

  Future<void> reopenSession(String sessionId) async {
    final teamId = _ref.read(activeTeamIdProvider);
    if (teamId == null) throw StateError('No active team selected');
    await _ref
        .read(sharedServiceProvider)
        .requireWrite(teamId, 'sport', sessionId: sessionId);
    await _repo.reopenSession(sessionId, teamId: teamId);
    await _ref.read(sharedServiceProvider).queueSport(teamId, sessionId);
    _invalidateAll(sessionId);
  }

  Future<void> deleteSession(String sessionId) async {
    final teamId = _ref.read(activeTeamIdProvider);
    if (teamId == null) return;
    await _ref
        .read(sharedServiceProvider)
        .requireWrite(teamId, 'sport', sessionId: sessionId);
    await _ref.read(sharedServiceProvider).cancelSport(teamId, sessionId);
    _invalidateAll(sessionId);
  }
}

final Provider<SessionsController> sessionsControllerProvider =
    Provider<SessionsController>((ref) {
      return SessionsController(ref);
    });
