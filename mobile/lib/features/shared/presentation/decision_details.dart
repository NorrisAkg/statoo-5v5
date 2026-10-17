import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String decisionAmount(Object? amount) => amount is num
    ? '${NumberFormat.decimalPattern('fr_FR').format(amount).replaceAll('\u202f', ' ').replaceAll('\u00a0', ' ')} F'
    : 'Non renseigné';

String decisionDate(Object? value) {
  final date = DateTime.tryParse('$value');
  return date == null
      ? 'Non renseignée'
      : DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(date.toLocal());
}

/// Des lignes identifiées par les clés métier, pour distinguer ajout/suppression
/// même lorsque les totaux ou les noms sont identiques.
Map<String, String> decisionRows(
  String domain,
  Map<String, dynamic> payload,
  Map<String, String> members,
) {
  final rows = <String, String>{};
  String member(Object? id) => '${members[id] ?? 'Membre inconnu'} ($id)';
  if (domain == 'finance') {
    rows['Date'] = decisionDate(payload['played_at']);
    rows['Cotisation attendue'] = decisionAmount(payload['rate']);
    rows['Séance annulée'] = payload['cancelled'] == true ? 'Oui' : 'Non';
    for (final line
        in (payload['lines'] as List? ?? [])
            .whereType<Map<String, dynamic>>()) {
      final name = member(line['member_id']);
      rows['Cotisation · $name'] = decisionAmount(line['contribution']);
      rows['Pénalité payée · $name'] = decisionAmount(line['penalty_paid']);
      rows['Pénalité due · $name'] = decisionAmount(line['penalty_due']);
      rows['Motif · $name'] = '${line['reason'] ?? 'Non renseigné'}';
    }
    for (final kind in ['expenses', 'donations']) {
      for (final movement
          in (payload[kind] as List? ?? []).whereType<Map<String, dynamic>>()) {
        rows['${kind == 'expenses' ? 'Dépense' : 'Don / recette'} · ${movement['id']}'] =
            '${movement['label'] ?? 'Sans motif'} : ${decisionAmount(movement['amount'])}';
      }
    }
  } else {
    final session = payload['session'] as Map<String, dynamic>? ?? {};
    rows['Date'] = decisionDate(session['played_at']);
    rows['Statut'] = switch (session['status']) {
      'CLOSED' => 'Clôturée',
      'DRAFT' => 'Brouillon',
      'CANCELLED' => 'Annulée',
      _ => 'Non renseigné',
    };
    rows['Séance classée'] =
        session['is_ranked'] == true || session['is_ranked'] == 1
        ? 'Oui'
        : 'Non';
    rows['Format'] = session['session_type'] == 'TOURNAMENT_3'
        ? 'Tournoi à 3 équipes'
        : 'Match à 2 équipes';
    rows['Résultat'] = '${session['result'] ?? 'Non renseigné'}';
    final rawNames = session['team_names'];
    Map<String, dynamic> names = const {};
    if (rawNames is Map<String, dynamic>) {
      names = rawNames;
    } else if (rawNames is String) {
      try {
        final decoded = jsonDecode(rawNames);
        if (decoded is Map<String, dynamic>) names = decoded;
      } on FormatException {
        /* Anciennes valeurs illisibles : noms A/B/C. */
      }
    }
    for (final team in [
      'A',
      'B',
      if (session['session_type'] == 'TOURNAMENT_3') 'C',
    ]) {
      final key = team.toLowerCase();
      rows['Équipe $team'] = '${names[team] ?? team}';
      rows['${session['session_type'] == 'TOURNAMENT_3' ? 'Victoires' : 'Score'} $team'] =
          '${session['session_type'] == 'TOURNAMENT_3' ? session['wins_$key'] ?? 'Non renseigné' : session['score_$key'] ?? 'Non renseigné'}';
      rows['Buts non attribués $team'] =
          '${session['unassigned_goals_$key'] ?? 0}';
    }
    rows['Points en cas d’égalité'] =
        '${session['draw_points'] ?? 'Non renseigné'}';
    rows['Équipes inégales autorisées'] =
        session['allow_uneven_teams'] == true ||
            session['allow_uneven_teams'] == 1
        ? 'Oui'
        : 'Non';
    rows['Notes'] = '${session['notes'] ?? ''}';
    for (final p
        in (payload['participations'] as List? ?? [])
            .whereType<Map<String, dynamic>>()) {
      final name = member(p['player_id']);
      rows['Équipe · $name'] = '${p['team'] ?? 'Non renseignée'}';
      for (final stat in {
        'goals': 'Buts',
        'assists': 'Passes décisives',
        'yellow_cards': 'Cartons jaunes',
        'red_cards': 'Cartons rouges',
      }.entries) {
        rows['${stat.value} · $name'] = '${p[stat.key] ?? 0}';
      }
    }
  }
  return rows;
}

class DecisionDetails extends StatelessWidget {
  const DecisionDetails({required this.rows, required this.others, super.key});
  final Map<String, String> rows;
  final List<Map<String, String>> others;
  @override
  Widget build(BuildContext context) {
    final keys = <String>{
      ...rows.keys,
      for (final other in others) ...other.keys,
    };
    final changed = keys
        .where((key) => others.any((other) => other[key] != rows[key]))
        .toList();
    final unchanged = keys.where((key) => !changed.contains(key)).toList();
    Widget line(String key, {required bool difference}) => Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(
        '${difference ? 'Différence · ' : ''}$key : ${rows[key] ?? 'Absent de cette version'}',
        style: TextStyle(
          fontWeight: difference ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (changed.isEmpty)
          const Text('Aucune différence avec les autres versions.'),
        for (final key in changed) line(key, difference: true),
        if (unchanged.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            title: Text('Détails inchangés (${unchanged.length})'),
            children: [
              for (final key in unchanged)
                Align(
                  alignment: Alignment.centerLeft,
                  child: line(key, difference: false),
                ),
            ],
          ),
      ],
    );
  }
}
