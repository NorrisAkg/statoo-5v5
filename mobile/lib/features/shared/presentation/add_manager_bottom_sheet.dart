import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/data/shared_http_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/player_sort.dart';
import '../../players/application/players_provider.dart';
import '../../players/domain/player.dart';
import '../application/shared_providers.dart';
import '../data/collective_access.dart';
import '../data/manager_password.dart';
import 'shared_group_screen.dart';

class AddManagerResult {
  const AddManagerResult({required this.success, this.warning});
  final bool success;
  final String? warning;
}

Future<AddManagerResult?> showAddManagerBottomSheet(BuildContext context) {
  return showModalBottomSheet<AddManagerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.background900,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      side: BorderSide(color: context.colors.background700),
    ),
    builder: (_) => const AddManagerBottomSheet(),
  );
}

class AddManagerBottomSheet extends ConsumerStatefulWidget {
  const AddManagerBottomSheet({super.key});

  @override
  ConsumerState<AddManagerBottomSheet> createState() =>
      _AddManagerBottomSheetState();
}

class _AddManagerBottomSheetState extends ConsumerState<AddManagerBottomSheet> {
  late final TextEditingController _memberSearch;
  late final TextEditingController _name;
  String? _nameError;
  String? _requestError;
  String? _createdWarning;
  var _sending = false;
  var _pickerOpen = false;
  String? _selectedMember;
  final _roles = <String>{};

  @override
  void initState() {
    super.initState();
    _memberSearch = TextEditingController();
    _name = TextEditingController();
  }

  @override
  void dispose() {
    _memberSearch.dispose();
    _name.dispose();
    super.dispose();
  }

  static String _normalize(String input) {
    var result = input.trim().toLowerCase();
    const diacritics = <String, String>{
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'á': 'a',
      'ã': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'í': 'i',
      'ô': 'o',
      'ö': 'o',
      'ó': 'o',
      'õ': 'o',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ú': 'u',
      'ÿ': 'y',
      'ç': 'c',
      'ñ': 'n',
      'œ': 'oe',
      'æ': 'ae',
    };
    diacritics.forEach((accented, plain) {
      result = result.replaceAll(accented, plain);
    });
    return result;
  }

  Future<void> _submit() async {
    final nameTrimmed = _name.text.trim();
    setState(() {
      _nameError = nameTrimmed.isEmpty
          ? 'Saisissez un identifiant.'
          : nameTrimmed.length > 100
          ? 'L’identifiant doit contenir au maximum 100 caractères.'
          : null;
      _requestError = null;
    });
    if (_nameError != null) return;

    setState(() => _sending = true);
    try {
      final service = ref.read(sharedServiceProvider);
      final group = service.groupId!;
      final originalUrl = service.baseUrl;
      final originalAdmin = service.accountId;
      final password = generateManagerPassword();

      final created = await service.request(
        'POST',
        '/groups/$group/accounts',
        {
          'username': nameTrimmed,
          'password': password,
          'member_id': _selectedMember,
          'roles': _roles.toList(),
        },
      );

      try {
        if (service.groupId != group ||
            service.baseUrl != originalUrl ||
            service.accountId != originalAdmin) {
          throw const CollectiveAccessException(
            'Le groupe ou le compte a changé.',
          );
        }
        await CollectiveAccess(
          service,
          group,
          managerAccountId: created['id'] as String,
        ).remember(password);
      } on Object {
        _createdWarning =
            'Compte créé. Son mot de passe n’a pas pu être mémorisé. Ouvrez ses accès pour générer un nouveau mot de passe.';
      }

      if (mounted) {
        setState(() => _sending = false);
        Navigator.pop(
          context,
          AddManagerResult(success: true, warning: _createdWarning),
        );
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _requestError = switch (error) {
          SharedNetworkException() =>
            'Impossible de joindre Statoo. Vérifiez votre connexion puis réessayez.',
          SharedApiException(statusCode: 409) =>
            'Cet identifiant ou ce membre est déjà associé à un compte. Vérifiez les comptes existants.',
          SharedApiException(statusCode: 422) =>
            'Les informations du compte sont invalides. Vérifiez les champs puis réessayez.',
          SharedApiException(statusCode: 401 || 403) =>
            'Vous n’avez plus l’autorisation de créer ce compte. Reconnectez-vous avec un accès Admin.',
          _ =>
            'Impossible de créer le compte pour le moment. Réessayez dans quelques instants.',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final players = [
      ...(ref.watch(playersListProvider).value ?? const <Player>[]),
    ]..sort(comparePlayersAlphabetically);

    final query = _normalize(_memberSearch.text);
    final filteredPlayers = query.isEmpty
        ? players
        : players.where((p) {
            final nameMatch = _normalize(p.name).contains(query);
            final nickMatch = p.nickname != null &&
                _normalize(p.nickname!).contains(query);
            return nameMatch || nickMatch;
          }).toList();

    return PopScope(
      canPop: !_sending,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.background700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Compte individuel et rôles',
                      style: TextStyle(
                        color: colors.foreground50,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    icon: const Icon(Remix.close_line),
                    onPressed:
                        _sending ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _memberSearch,
                        enabled: !_sending,
                        onTap: () => setState(() => _pickerOpen = true),
                        onChanged: (_) => setState(() {
                          _selectedMember = null;
                          _pickerOpen = true;
                        }),
                        onSubmitted: (_) {
                          if (filteredPlayers.isNotEmpty) {
                            final first = filteredPlayers.first;
                            _memberSearch.text = first.name;
                            setState(() {
                              _selectedMember = first.id;
                              _pickerOpen = false;
                            });
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Membre',
                          hintText: 'Rechercher un joueur par nom…',
                          prefixIcon: Icon(
                            Remix.search_line,
                            color: colors.foreground400,
                            size: 20,
                          ),
                          suffixIcon: _memberSearch.text.isNotEmpty
                              ? IconButton(
                                  tooltip: 'Effacer la recherche',
                                  onPressed: _sending
                                      ? null
                                      : () => setState(() {
                                            _memberSearch.clear();
                                            _selectedMember = null;
                                            _pickerOpen = true;
                                          }),
                                  icon: Icon(
                                    Remix.close_line,
                                    color: colors.foreground400,
                                    size: 20,
                                  ),
                                )
                              : IconButton(
                                  tooltip: _pickerOpen
                                      ? 'Masquer la liste des membres'
                                      : 'Afficher la liste des membres',
                                  onPressed: _sending
                                      ? null
                                      : () =>
                                          setState(() => _pickerOpen = !_pickerOpen),
                                  icon: Icon(
                                    _pickerOpen
                                        ? Remix.arrow_up_s_line
                                        : Remix.arrow_down_s_line,
                                    color: colors.foreground400,
                                    size: 20,
                                  ),
                                ),
                        ),
                      ),
                      if (_pickerOpen) ...[
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            color: colors.background800,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.background700),
                          ),
                          child: filteredPlayers.isEmpty
                              ? ConstrainedBox(
                                  constraints: const BoxConstraints(minHeight: 48),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Aucun joueur trouvé',
                                        style: TextStyle(
                                          color: colors.foreground400,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      for (final p in filteredPlayers)
                                        InkWell(
                                          borderRadius: BorderRadius.circular(12),
                                          onTap: _sending
                                              ? null
                                              : () {
                                                  _memberSearch.text = p.name;
                                                  setState(() {
                                                    _selectedMember = p.id;
                                                    _pickerOpen = false;
                                                  });
                                                },
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              minHeight: 48,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      p.name,
                                                      style: TextStyle(
                                                        color: colors.foreground50,
                                                        fontWeight:
                                                            _selectedMember == p.id
                                                                ? FontWeight.w600
                                                                : FontWeight.w400,
                                                      ),
                                                    ),
                                                  ),
                                                  if (_selectedMember == p.id)
                                                    Icon(
                                                      Remix.check_line,
                                                      color: colors.primary400,
                                                      size: 18,
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _name,
                        enabled: !_sending,
                        decoration: InputDecoration(
                          labelText: 'Identifiant',
                          hintText: 'Ex. : alice',
                          errorText: _nameError,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Un mot de passe de 8 caractères sera généré automatiquement.',
                      ),
                      for (final entry in roleLabels.entries.where(
                        (e) => e.key != 'ADMIN' && e.key != 'MEMBER',
                      ))
                        CheckboxListTile(
                          title: Text(entry.value),
                          value: _roles.contains(entry.key),
                          onChanged: _sending
                              ? null
                              : (value) => setState(() {
                                  if (value == true) {
                                    _roles.add(entry.key);
                                  } else {
                                    _roles.remove(entry.key);
                                  }
                                }),
                        ),
                      if (_requestError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _requestError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Text('Sélectionnez au moins un rôle de responsable.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _sending ? null : () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ||
                            _selectedMember == null ||
                            _roles.isEmpty
                        ? null
                        : _submit,
                    child: const Text('Créer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
