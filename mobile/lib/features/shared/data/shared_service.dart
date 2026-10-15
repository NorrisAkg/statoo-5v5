import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/data/app_database.dart';
import '../../../core/data/occurrence_registry.dart';

class SharedService {
  SharedService(this.database, {FlutterSecureStorage? storage})
    : storage = storage ?? const FlutterSecureStorage();
  final AppDatabase database;
  final FlutterSecureStorage storage;
  Map<String, dynamic>? identity;
  Map<String, dynamic>? snapshot;
  String? baseUrl;
  String? token;
  String? get accountId => (identity?['account'] as Map?)?['id'] as String?;
  String? get groupId => identity?['group_id'] as String?;
  List<String> get roles =>
      ((identity?['account'] as Map?)?['roles'] as List?)?.cast<String>() ??
      const [];
  bool get connected => identity != null;
  final Set<String> protectedGroups = {};
  bool get identityValid {
    final expiry = DateTime.tryParse('${identity?['expires_at'] ?? ''}');
    return expiry != null && DateTime.now().toUtc().isBefore(expiry.toUtc());
  }
  bool canWrite(String? group, String domain) =>
      group != null && (
        (!protectedGroups.contains(group) && group != groupId) ||
        (connected && group == groupId && identityValid && permits(domain))
      );
  bool permits(String domain) => (identity?['account'] as Map?)?['shared'] != true && roles.any(
    (r) =>
        (domain == 'sport'
                ? ['SG', 'SGA']
                : domain == 'finance_settings'
                ? ['ADMIN', 'TR', 'TGA']
                : domain == 'finance'
                ? ['TR', 'TGA']
                : ['ADMIN'])
            .contains(r),
  );
  Timer? _timer;
  bool _syncing = false;
  void Function()? onChanged;
  void dispose() => _timer?.cancel();

  Future<void> load() async {
    final localDb = await database.database;
    final sharedGroups = await localDb.query(
      'meta',
      where: 'substr(key,1,13) = ?',
      whereArgs: ['shared_group_'],
    );
    protectedGroups.addAll(
      sharedGroups.map((r) => (r['key']! as String).substring(13)),
    );
    final value = await storage.read(key: 'statoo_connection');
    if (value != null) {
      final saved = jsonDecode(value) as Map<String, dynamic>;
      identity = saved['identity'] as Map<String, dynamic>;
      baseUrl = saved['url'] as String;
      token = saved['token'] as String;
      final db = await database.database;
      final rows = await db.query(
        'meta',
        where: 'key = ?',
        whereArgs: ['shared_snapshot_$groupId'],
      );
      if (rows.isNotEmpty) {
        snapshot =
            jsonDecode(rows.single['value']! as String) as Map<String, dynamic>;
      }
      startAutomaticSync();
    }
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Object? body,
  ]) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final req = await client.openUrl(
        method,
        Uri.parse('$baseUrl${path.replaceAll('#', '%23')}'),
      );
      if (token != null) req.headers.set('Authorization', 'Bearer $token');
      req.headers.contentType = ContentType.json;
      if (body != null) req.write(jsonEncode(body));
      final response = await req.close().timeout(const Duration(seconds: 90));
      final content = await utf8.decoder.bind(response).join();
      if (response.statusCode >= 400) {
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        throw HttpException('${response.statusCode}: ${decoded['detail']}');
      }
      return jsonDecode(content) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> connect(
    String url,
    String group,
    String username,
    String password, {
    Map<String, dynamic>? registration,
  }) async {
    final uri = Uri.parse(url.trim());
    if (uri.scheme != 'https' &&
        !(uri.scheme == 'http' &&
            ['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host))) {
      throw const FormatException(
        'Utilisez une adresse HTTPS (HTTP seulement en développement local).',
      );
    }
    baseUrl = url.trim().replaceAll(RegExp(r'/$'), '');
    token = null;
    final result = await request(
      'POST',
      registration == null ? '/auth/login' : '/groups',
      registration ??
          {'group_id': group, 'username': username, 'password': password},
    );
    identity = result;
    token = result['token'] as String;
    await storage.write(
      key: 'statoo_connection',
      value: jsonEncode({'identity': result, 'url': baseUrl, 'token': token}),
    );
    protectedGroups.add(groupId!);
    final db = await database.database;
    await db.insert('meta', {
      'key': 'shared_group_$groupId',
      'value': '1',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await synchronize();
    startAutomaticSync();
  }

  void startAutomaticSync() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(synchronize().catchError((Object _) {}));
    });
  }

  Future<void> disconnect() async {
    if (connected) await request('POST', '/auth/logout');
    await storage.delete(key: 'statoo_connection');
    identity = null;
    token = null;
    snapshot = null;
    _timer?.cancel();
  }

  Future<void> requireWrite(
    String group,
    String domain, {
    String? sessionId,
  }) async {
    // Existing personal groups remain usable until explicitly connected to the service.
    final localDb = await database.database;
    final marker = await localDb.query(
      'meta',
      where: 'key = ?',
      whereArgs: ['shared_group_$group'],
    );
    if (marker.isNotEmpty) protectedGroups.add(group);
    if (!protectedGroups.contains(group) && group != groupId) {
      if (connected) {
        final local = await localDb.query('teams', columns: ['id'], where: 'id = ?', whereArgs: [group]);
        if (local.isEmpty) throw StateError('Groupe local introuvable ou autre groupe partagé.');
      }
      return;
    }
    if (!connected) {
      if (protectedGroups.contains(group)) {
        throw StateError('Reconnectez-vous pour modifier ce groupe partagé.');
      }
      return;
    }
    if (!identityValid) {
      throw StateError('Connexion expirée ; reconnectez-vous en ligne.');
    }
    if (group != groupId || !permits(domain)) {
      throw StateError('Vous ne disposez pas du rôle requis.');
    }
    if (sessionId != null) {
      final db = await database.database;
      final owner = await db.query(
        'meta',
        where: 'key = ?',
        whereArgs: ['shared_owner_${domain}_$sessionId'],
      );
      if (owner.isNotEmpty && owner.single['value'] != accountId) {
        throw StateError('Cette séance a un autre responsable.');
      }
    }
  }

  String operationId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<void> enqueue(
    DatabaseExecutor db,
    String group,
    String domain,
    String sessionId,
    Map<String, dynamic> payload, {
    String reason = '',
  }) async {
    if (!connected || group != groupId) return;
    final day =
        (domain == 'finance'
                ? payload['played_at']
                : (payload['session'] as Map)['played_at'])
            as String;
    final identity = await reserveOccurrence(db, group, sessionId, DateTime.parse(day));
    final occurrence = identity.reference;
    final revisionRows = await db.query(
      'meta',
      where: 'key = ?',
      whereArgs: ['shared_revision_${domain}_$sessionId'],
    );
    final generationRows = await db.query(
      'meta',
      where: 'key = ?',
      whereArgs: ['shared_generation_${domain}_$sessionId'],
    );
    final waiting = await db.query(
      'meta',
      where: 'substr(key,1,7) = ?',
      whereArgs: ['outbox_'],
    );
    for (final row in waiting) {
      final old = jsonDecode(row['value']! as String) as Map;
      if (old['status'] == 'pending' &&
          old['attempted'] != true &&
          old['actor'] == accountId &&
          old['domain'] == domain &&
          old['group_id'] == group &&
          old['local_session_id'] == sessionId) {
        await db.delete('meta', where: 'key = ?', whereArgs: [row['key']]);
      }
    }
    if (domain == 'finance') {
      await db.insert('meta', {
        'key': 'shared_finance_alias_${groupId}_$occurrence',
        'value': sessionId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    final id = operationId();
    await db.insert('meta', {
      'key': 'outbox_$id',
      'value': jsonEncode({
        'operation_id': id,
        'occurrence_id': occurrence,
        'domain': domain,
        'base_revision': revisionRows.isEmpty
            ? 0
            : int.parse(revisionRows.single['value']! as String),
        'generation': generationRows.isEmpty
            ? 0
            : int.parse(generationRows.single['value']! as String),
        'payload': payload,
        'reason': reason.isEmpty ? 'Saisie de séance' : reason,
        'local_session_id': sessionId,
        'group_id': group,
        'status': 'pending',
        'actor': accountId,
      }),
    }, conflictAlgorithm: ConflictAlgorithm.abort);
    await db.insert('meta', {
      'key': 'shared_owner_${domain}_$sessionId',
      'value': accountId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> queueSport(
    String group,
    String sessionId, {
    bool cancelled = false,
  }) async {
    if (!connected || group != groupId) return;
    final db = await database.database;
    final sessionRows = await db.query(
      'sessions',
      where: 'id = ? AND team_id = ?',
      whereArgs: [sessionId, group],
    );
    if (sessionRows.isEmpty) return;
    final parts = await db.query(
      'participations',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    final row = Map<String, dynamic>.from(sessionRows.single);
    if (cancelled) row['status'] = 'CANCELLED';
    await db.transaction(
      (txn) => enqueue(
        txn,
        group,
        'sport',
        sessionId,
        {
          'session': row,
          'participations': cancelled ? <Map<String, dynamic>>[] : parts,
        },
        reason: cancelled
            ? 'Annulation de la séance'
            : 'Actualisation de la séance',
      ),
    );
  }

  Future<void> cancelSport(String group, String sessionId) async {
    final db = await database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'sessions',
        where: 'id = ? AND team_id = ?',
        whereArgs: [sessionId, group],
      );
      if (rows.isEmpty) return;
      final occurrence = await txn.query(
        'meta',
        where: 'key = ?',
        whereArgs: ['shared_occurrence_$sessionId'],
      );
      final alias = occurrence.isEmpty
          ? <Map<String, Object?>>[]
          : await txn.query(
              'meta',
              where: 'key = ?',
              whereArgs: [
                'shared_finance_alias_${group}_${occurrence.single['value']}',
              ],
            );
      final financialId = alias.isEmpty
          ? sessionId
          : alias.single['value']! as String;
      final key = 'finance_point_${group}_$financialId';
      final points = await txn.query(
        'meta',
        where: 'key = ?',
        whereArgs: [key],
      );
      if (points.isNotEmpty) {
        final point = jsonDecode(
          points.single['value']! as String,
        ) as Map<String, dynamic>;
        final lines = (point['lines'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        if (lines.any(
              (l) =>
                  l['contribution'] != 0 ||
                  l['penalty_paid'] != 0 ||
                  l['penalty_due'] != 0,
            ) ||
            (point['expenses'] as List).isNotEmpty ||
            (point['donations'] as List).isNotEmpty) {
          throw StateError(
            'Le trésorier doit corriger le point financier avant l’annulation.',
          );
        }
        point['cancelled'] = true;
        await txn.update(
          'meta',
          {'value': jsonEncode(point)},
          where: 'key = ?',
          whereArgs: [key],
        );
      }
      if (connected && group == groupId) {
        await enqueue(txn, group, 'sport', sessionId, {
          'session': {...rows.single, 'status': 'CANCELLED'},
          'participations': <dynamic>[],
        }, reason: 'Annulation de la séance');
      }
      await txn.delete(
        'sessions',
        where: 'id = ? AND team_id = ?',
        whereArgs: [sessionId, group],
      );
      await txn.delete(
        'meta',
        where: 'key = ? AND value = ?',
        whereArgs: ['active_session_id_$group', sessionId],
      );
    });
  }

  Future<void> synchronize() async {
    if (!connected || _syncing) return;
    _syncing = true;
    try {
      final db = await database.database;
      snapshot = await request('GET', '/groups/$groupId');
      identity!['account'] = snapshot!['account'];
      await importSnapshot(snapshot!);
      final pending = await db.query(
        'meta',
        where: 'substr(key,1,7) = ?',
        whereArgs: ['outbox_'],
        orderBy: 'rowid',
      );
      for (final row in pending) {
        final event =
            jsonDecode(row['value']! as String) as Map<String, dynamic>;
        if (event['status'] != 'pending' ||
            event['group_id'] != groupId ||
            event['actor'] != accountId) {
          continue;
        }
        if (event['attempted'] != true) {
          final rows = await db.query(
            'meta',
            where: 'key = ?',
            whereArgs: [
              'shared_revision_${event['domain']}_${event['local_session_id']}',
            ],
          );
          if (rows.isNotEmpty) {
            event['base_revision'] = int.parse(rows.single['value']! as String);
          }
          event['attempted'] = true;
          await db.update(
            'meta',
            {'value': jsonEncode(event)},
            where: 'key = ?',
            whereArgs: [row['key']],
          );
        }
        final wire = Map<String, dynamic>.from(event)
          ..remove('local_session_id')
          ..remove('group_id')
          ..remove('status')
          ..remove('actor')
          ..remove('attempted');
        final result = await request('POST', '/groups/$groupId/sync', wire);
        event['status'] = result['status'];
        await db.update(
          'meta',
          {'value': jsonEncode(event)},
          where: 'key = ?',
          whereArgs: [row['key']],
        );
        if (result['status'] == 'conflict' && event['domain'] == 'sport') {
          await db.update(
            'sessions',
            {'status': 'DRAFT'},
            where: 'id = ? AND team_id = ?',
            whereArgs: [event['local_session_id'], groupId],
          );
        }
        if (result['status'] == 'accepted') {
          await db.insert('meta', {
            'key':
                'shared_revision_${event['domain']}_${event['local_session_id']}',
            'value': '${result['revision']}',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      snapshot = await request('GET', '/groups/$groupId');
      identity!['account'] = snapshot!['account'];
      await storage.write(
        key: 'statoo_connection',
        value: jsonEncode({
          'identity': identity,
          'url': baseUrl,
          'token': token,
        }),
      );
      await importSnapshot(snapshot!);
    } finally {
      _syncing = false;
    }
  }

  Future<void> importSnapshot(Map<String, dynamic> data) async {
    final db = await database.database;
    await db.transaction((txn) async {
      await txn.insert('teams', {
        'id': groupId,
        'name': data['name'],
        'format': '5v5',
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.insert('meta', {
        'key': 'shared_snapshot_$groupId',
        'value': jsonEncode(data),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      final settings = data['financial_settings'] as Map?;
      if (settings != null) {
        await txn.insert('meta', {
          'key': 'finance_rate_$groupId',
          'value': '${settings['contribution']}',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await txn.insert('meta', {
          'key': 'finance_late_penalty_$groupId',
          'value': '${settings['late_penalty']}',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final member in data['members'] as List<dynamic>) {
        final row = Map<String, dynamic>.from(member as Map);
        row.removeWhere(
          (key, _) => !{
            'id',
            'name',
            'nickname',
            'avatar_url',
            'is_active',
            'created_at',
            'updated_at',
          }.contains(key),
        );
        row['team_id'] = groupId;
        row.putIfAbsent('created_at', () => DateTime.now().toIso8601String());
        row.putIfAbsent('updated_at', () => row['created_at']);
        final existing = await txn.query(
          'players',
          where: 'id = ?',
          whereArgs: [row['id']],
        );
        if (existing.isNotEmpty && existing.single['team_id'] != groupId) {
          throw StateError('Identifiant de membre d’un autre groupe.');
        }
        if (existing.isEmpty) {
          await txn.insert('players', row);
        } else {
          await txn.update(
            'players',
            row,
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
      final documents = data['documents'] as Map<String, dynamic>;
      for (final entry in (data['obligations'] as Map? ?? {}).entries) {
        if (documents.containsKey('finance:${entry.key}')) continue;
        final reference = entry.key as String;
        final aliases = await txn.query(
          'meta',
          where: 'key = ?',
          whereArgs: ['shared_finance_alias_${groupId}_$reference'],
        );
        final financialId = aliases.isEmpty
            ? 'remote_${groupId}_$reference'
            : aliases.single['value']! as String;
        await txn.insert('meta', {
          'key': 'shared_finance_alias_${groupId}_$reference',
          'value': financialId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await txn.insert('meta', {
          'key': 'shared_occurrence_$financialId',
          'value': reference,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await txn.insert('meta', {
          'key': 'finance_point_${groupId}_$financialId',
          'value': jsonEncode(entry.value),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final raw in documents.values) {
        final document = raw as Map<String, dynamic>;
        final domain = document['domain'] as String;
        final payload = document['payload'] as Map<String, dynamic>;
        final occurrence = document['occurrence_id'] as String;
        String id;
        if (domain == 'sport') {
          id = (payload['session'] as Map)['id'] as String;
        } else {
          final alias = await txn.query(
            'meta',
            where: 'key = ?',
            whereArgs: ['shared_finance_alias_${groupId}_$occurrence'],
          );
          final matching = documents.values
              .cast<Map<String, dynamic>>()
              .where(
                (v) =>
                    v['domain'] == 'sport' && v['occurrence_id'] == occurrence,
              )
              .firstOrNull;
          id = alias.isNotEmpty
              ? alias.single['value']! as String
              : matching == null
              ? 'remote_${groupId}_$occurrence'
              : ((matching['payload'] as Map<String, dynamic>)['session']
                        as Map<String, dynamic>)['id']
                    as String;
          await txn.insert('meta', {
            'key': 'shared_finance_alias_${groupId}_$occurrence',
            'value': id,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        final events = await txn.query(
          'meta',
          where: 'substr(key,1,7) = ?',
          whereArgs: ['outbox_'],
        );
        var pending = false;
        for (final row in events) {
          final event =
              jsonDecode(row['value']! as String) as Map<String, dynamic>;
          if (event['group_id'] != groupId ||
              event['domain'] != domain ||
              event['occurrence_id'] != occurrence) {
            continue;
          }
          if (event['status'] == 'pending') pending = true;
          if (event['status'] == 'conflict') {
            final unresolved = (document['candidates'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>()
                .any((c) => c['id'] == event['operation_id']);
            // A later revision signals an explicit decision; retain the original event as history.
            if (!unresolved &&
                (document['revision'] as int) >
                    (event['base_revision'] as int) + 1) {
              event['status'] = 'resolved';
              await txn.update(
                'meta',
                {'value': jsonEncode(event)},
                where: 'key = ?',
                whereArgs: [row['key']],
              );
            }
            if (domain == 'sport' && event['local_session_id'] != id) {
              await txn.update(
                'sessions',
                {'status': 'DRAFT'},
                where: 'id = ? AND team_id = ?',
                whereArgs: [event['local_session_id'], groupId],
              );
            }
          }
        }
        if (pending) continue;
        if (domain == 'sport') {
          final session = Map<String, dynamic>.from(payload['session'] as Map)
            ..['team_id'] = groupId;
          final existing = await txn.query(
            'sessions',
            where: 'id = ?',
            whereArgs: [id],
          );
          if (existing.isNotEmpty && existing.single['team_id'] != groupId) {
            throw StateError('Identifiant de séance d’un autre groupe.');
          }
          if (session['status'] == 'CANCELLED') {
            await txn.delete(
              'sessions',
              where: 'id = ? AND team_id = ?',
              whereArgs: [id, groupId],
            );
          } else {
            if (existing.isEmpty) {
              await txn.insert('sessions', session);
            } else {
              await txn.update(
                'sessions',
                session,
                where: 'id = ?',
                whereArgs: [id],
              );
            }
            await txn.delete(
              'participations',
              where: 'session_id = ?',
              whereArgs: [id],
            );
            for (final part in payload['participations'] as List<dynamic>) {
              await txn.insert(
                'participations',
                Map<String, dynamic>.from(part as Map),
              );
            }
          }
        } else {
          await txn.insert('meta', {
            'key': 'finance_point_${groupId}_$id',
            'value': jsonEncode(payload),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await txn.insert('meta', {
          'key': 'shared_occurrence_$id',
          'value': occurrence,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        for (final field in ['owner', 'revision', 'generation']) {
          await txn.insert('meta', {
            'key': 'shared_${field}_${domain}_$id',
            'value': '${document[field]}',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
    onChanged?.call();
  }
}
