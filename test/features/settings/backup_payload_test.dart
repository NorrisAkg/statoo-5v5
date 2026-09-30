import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/features/settings/domain/backup_payload.dart';

void main() {
  group('BackupPayload.fromJson validation', () {
    test('throws FormatException when json is empty (B-01 protection)', () {
      expect(
        () => BackupPayload.fromJson({}),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('sauvegarde Statoo valide'),
        )),
      );
    });

    test('throws FormatException when json has no teams (B-01 protection)', () {
      final invalidJson = {
        'version': 1,
        'app': 'statoo_5v5',
        'players': <dynamic>[],
        'sessions': <dynamic>[],
        'participations': <dynamic>[],
      };

      expect(
        () => BackupPayload.fromJson(invalidJson),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('aucune équipe'),
        )),
      );
    });

    test('throws FormatException when app identifier is for another app', () {
      final foreignJson = {
        'app': 'other_football_app',
        'version': 1,
        'team': {'id': 't1', 'name': 'Team 1'},
      };

      expect(
        () => BackupPayload.fromJson(foreignJson),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('autre application'),
        )),
      );
    });

    test('parses legacy single-team (v1) backup and exposes teams list', () {
      final v1Json = {
        'version': 1,
        'app': 'statoo_5v5',
        'exported_at': '2026-09-25T14:30:00.000Z',
        'team': {'id': 'team_legacy', 'name': 'Legacy Team'},
        'players': [
          {'id': 'p1', 'name': 'Zidane', 'team_id': 'team_legacy'},
        ],
        'sessions': <dynamic>[],
        'participations': <dynamic>[],
      };

      final payload = BackupPayload.fromJson(v1Json);
      expect(payload.version, 1);
      expect(payload.team?['id'], 'team_legacy');
      expect(payload.teams.length, 1);
      expect(payload.teams.first['id'], 'team_legacy');
      expect(payload.players.length, 1);
    });

    test('parses multi-team (v2) backup and exposes all teams', () {
      final v2Json = {
        'version': 2,
        'app': 'statoo_5v5',
        'exported_at': '2026-09-30T10:00:00.000Z',
        'teams': [
          {'id': 'team_alpha', 'name': 'Alpha'},
          {'id': 'team_beta', 'name': 'Beta'},
        ],
        'players': [
          {'id': 'p1', 'name': 'Player A', 'team_id': 'team_alpha'},
          {'id': 'p2', 'name': 'Player B', 'team_id': 'team_beta'},
        ],
        'sessions': <dynamic>[],
        'participations': <dynamic>[],
      };

      final payload = BackupPayload.fromJson(v2Json);
      expect(payload.version, 2);
      expect(payload.teams.length, 2);
      expect(payload.teams.map((t) => t['name']), containsAll(['Alpha', 'Beta']));
      expect(payload.team?['name'], 'Alpha');
      expect(payload.players.length, 2);
    });

    test('toJson serializes with version 2 and teams list', () {
      final payload = BackupPayload(
        version: 2,
        exportedAt: DateTime(2026, 9, 30),
        team: {'id': 't1', 'name': 'Team 1'},
        teams: [
          {'id': 't1', 'name': 'Team 1'},
          {'id': 't2', 'name': 'Team 2'},
        ],
        players: [],
        sessions: [],
        participations: [],
      );

      final json = payload.toJson();
      expect(json['version'], 2);
      expect(json['app'], 'statoo_5v5');
      expect((json['teams'] as List).length, 2);
      expect((json['team'] as Map<String, dynamic>?)?['id'], 't1');
    });
  });
}
