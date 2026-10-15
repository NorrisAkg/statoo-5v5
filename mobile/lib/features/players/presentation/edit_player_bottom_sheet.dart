import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../shared/application/shared_providers.dart';
import '../../team/application/team_provider.dart';
import '../application/players_provider.dart';
import '../domain/player.dart';

class EditPlayerBottomSheet extends ConsumerStatefulWidget {
  const EditPlayerBottomSheet({required this.player, super.key});

  final Player player;

  @override
  ConsumerState<EditPlayerBottomSheet> createState() =>
      _EditPlayerBottomSheetState();
}

class _EditPlayerBottomSheetState extends ConsumerState<EditPlayerBottomSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _nicknameController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.player.name);
    _nicknameController = TextEditingController(
      text: widget.player.nickname ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final name = _nameController.text.trim();
      final taken = await ref
          .read(playersListProvider.notifier)
          .isNameTaken(name, excludePlayerId: widget.player.id);
      if (!mounted) return;
      if (ref.read(activeTeamIdProvider) != widget.player.teamId)
        throw StateError(
          'Le groupe actif a changé. Rouvrez ce joueur dans son groupe.',
        );
      if (taken) {
        setState(() {
          _nameError =
              'Un joueur nommé « $name » existe déjà. Modifiez légèrement le nom.';
        });
        return;
      }

      await ref
          .read(playersListProvider.notifier)
          .updatePlayer(
            id: widget.player.id,
            name: name,
            nickname: _nicknameController.text.trim().isNotEmpty
                ? _nicknameController.text.trim()
                : null,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Joueur "$name" mis à jour.')));
      }
    } on Object catch (error) {
      if (mounted)
        setState(() => _nameError = 'Modification impossible : $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final writable =
        ref.watch(canWriteProvider('members')) &&
        ref.watch(activeTeamIdProvider) == widget.player.teamId;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.background900,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!writable)
                  const Text(
                    'Consultation uniquement. Le rôle ADMIN est requis pour gérer les joueurs.',
                  ),
                if (_nameError != null)
                  Semantics(liveRegion: true, child: Text(_nameError!)),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.colors.background700,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Modifier le joueur',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Remix.close_line),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  enabled: writable && !_isSaving,
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nom ou Prénom *',
                    hintText: 'Ex: Lucas',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  autofocus: true,
                  onChanged: (_) {
                    if (_nameError != null) {
                      setState(() => _nameError = null);
                    }
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le nom est obligatoire';
                    }
                    return null;
                  },
                ),
                if (_nameError != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Remix.error_warning_line,
                        size: 14,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _nameError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  enabled: writable && !_isSaving,
                  controller: _nicknameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Surnom (optionnel)',
                    hintText: 'Ex: Lulu',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: _isSaving
                      ? 'Enregistrement...'
                      : 'Enregistrer les modifications',
                  onPressed: !writable || _isSaving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
