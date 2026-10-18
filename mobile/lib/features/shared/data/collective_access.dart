import 'dart:convert';

import '../../../core/data/shared_http_error.dart';
import 'collective_access_key.dart';
import 'manager_password.dart';
import 'shared_service.dart';

class CollectiveAccess {
  CollectiveAccess(this.service, this.group, {this.managerAccountId});
  final String? managerAccountId;
  Future<void> regenerate() async {
    final key = _scope();
    if (managerAccountId == null || managerAccountId == service.accountId) {
      throw const CollectiveAccessException(
        'Choisissez un autre gestionnaire.',
      );
    }
    final password = generateManagerPassword();
    await service.request(
      'POST',
      '/groups/$group/accounts/$managerAccountId/password',
      {'password': password},
    );
    _check(key);
    try {
      await remember(password);
    } on Object {
      throw const CollectiveAccessException(
        'Le mot de passe a été remplacé, mais sa mémorisation a échoué. Générez-en un nouveau pour récupérer les accès.',
      );
    }
  }

  final SharedService service;
  final String group;
  String? get _key {
    final base = collectiveAccessKey(
      service.baseUrl,
      service.groupId,
      service.accountId,
    );
    if (base == null || managerAccountId == null) return base;
    return '${base}_manager_${base64Url.encode(utf8.encode(managerAccountId!))}';
  }

  bool get allowed =>
      service.connected &&
      service.identityValid &&
      service.groupId == group &&
      service.roles.contains('ADMIN') &&
      (service.identity?['account'] as Map?)?['shared'] != true &&
      _key != null;
  String _scope() {
    if (!allowed) {
      throw const CollectiveAccessException(
        'Accès réservé à l’Admin connecté à ce groupe.',
      );
    }
    return _key!;
  }

  void _check(String key) {
    if (!allowed || key != _key) {
      throw const CollectiveAccessException(
        'Le groupe ou le compte a changé. Réessayez.',
      );
    }
  }

  Future<bool> hasSaved() async {
    if (!allowed) return false;
    final key = _scope();
    final value = await service.storage.read(key: key);
    _check(key);
    return value != null;
  }

  Future<Map<String, dynamic>> _verify(String password, String key) async {
    final result = await service.request(
      'POST',
      managerAccountId == null
          ? '/groups/$group/shared-access/verify'
          : '/groups/$group/accounts/$managerAccountId/password/verify',
      {'password': password},
    );
    _check(key);
    if (result['verified'] != true ||
        result['group_id'] != group ||
        result['username'] is! String) {
      throw const CollectiveAccessException(
        'La vérification des accès a échoué.',
      );
    }
    return result;
  }

  Future<void> remember(String password) async {
    final key = _scope();
    if (password.length < 8 || password.length > 200) {
      throw const CollectiveAccessException(
        'Le mot de passe doit contenir entre 8 et 200 caractères.',
      );
    }
    await _verify(password, key);
    await service.storage.write(key: key, value: password);
    if (!allowed || key != _key) {
      await service.storage.delete(key: key);
      throw const CollectiveAccessException(
        'Le groupe ou le compte a changé. Réessayez.',
      );
    }
  }

  Future<String> copyText(String name) async {
    final key = _scope();
    final password = await service.storage.read(key: key);
    _check(key);
    if (password == null) {
      throw const CollectiveAccessException(
        'Renseignez le mot de passe commun.',
      );
    }
    try {
      final result = await _verify(password, key);
      if (managerAccountId != null) {
        return 'Accès gestionnaire au groupe $name\nIdentifiant du groupe : $group\nIdentifiant personnel : ${result['username']}\nMot de passe : $password';
      }
      return 'Accès au groupe $name\nIdentifiant du groupe : $group\nIdentifiant commun : ${result['username']}\nMot de passe commun : $password\nAccès en lecture seule.';
    } on SharedApiException catch (error) {
      if ([400, 401, 403].contains(error.statusCode)) {
        await service.storage.delete(key: key);
      }
      rethrow;
    }
  }

  Future<void> forget() async {
    final key = _scope();
    await service.storage.delete(key: key);
  }
}

class CollectiveAccessException implements Exception {
  const CollectiveAccessException(this.message);
  final String message;
  @override
  String toString() => message;
}
