import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/data/shared_http_error.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../shared/data/collective_access.dart';

class CollectiveAccessSection extends StatefulWidget {
  const CollectiveAccessSection({
    required this.access,
    required this.groupName,
    this.managerName,
    super.key,
  });
  final CollectiveAccess access;
  final String groupName;
  final String? managerName;
  @override
  State<CollectiveAccessSection> createState() =>
      _CollectiveAccessSectionState();
}

class _CollectiveAccessSectionState extends State<CollectiveAccessSection> {
  bool get manager => widget.access.managerAccountId != null;
  bool saved = false;
  bool busy = false;
  String? error;
  String? notice;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final value = await widget.access.hasSaved();
      if (mounted) setState(() => saved = value);
    } on Object {
      if (mounted) {
        setState(
          () => error =
              'Impossible de lire les accès mémorisés sur cet appareil.',
        );
      }
    }
  }

  String _message(Object failure) => switch (failure) {
    final SharedApiException e => e.message,
    final SharedNetworkException e => e.toString(),
    final CollectiveAccessException e => e.message,
    _ => 'Impossible de terminer cette action sur cet appareil. Réessayez.',
  };
  Future<void> _edit() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    final controller = TextEditingController();
    bool submitting = false;
    bool visible = false;
    String? dialogError;
    try {
      await showAppFormDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => PopScope(
            canPop: !submitting,
            child: AlertDialog(
              title: Text(
                manager
                    ? 'Vérifier le mot de passe du gestionnaire'
                    : 'Vérifier le mot de passe commun',
              ),
              scrollable: true,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    manager
                        ? 'Saisissez le mot de passe actuel de ce gestionnaire. Il sera vérifié puis mémorisé sur cet appareil, sans être modifié.'
                        : 'Saisissez le mot de passe déjà utilisé par les membres. Il sera vérifié puis mémorisé sur cet appareil, sans être modifié.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: !visible,
                    enabled: !submitting,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: manager
                          ? 'Mot de passe du gestionnaire'
                          : 'Mot de passe commun',
                      hintText: 'Au moins 8 caractères',
                      suffixIcon: IconButton(
                        tooltip: visible
                            ? 'Masquer le mot de passe'
                            : 'Afficher le mot de passe',
                        onPressed: submitting
                            ? null
                            : () => update(() => visible = !visible),
                        icon: Icon(
                          visible ? Remix.eye_off_line : Remix.eye_line,
                        ),
                      ),
                    ),
                  ),
                  if (dialogError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        dialogError!,
                        semanticsLabel: dialogError,
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          update(() {
                            submitting = true;
                            dialogError = null;
                          });
                          try {
                            await widget.access.remember(controller.text);
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                          } on Object catch (failure) {
                            if (ctx.mounted) {
                              update(() {
                                submitting = false;
                                dialogError = _message(failure);
                              });
                            }
                          }
                        },
                  child: Text(
                    submitting ? 'Vérification…' : 'Vérifier et mémoriser',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await _load();
    } finally {
      controller.dispose();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _regenerate() async {
    if (busy) return;
    setState(() => busy = true);
    final accepted = await showAppFormDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remplacer le mot de passe ?'),
        scrollable: true,
        content: Text(
          'Un nouveau mot de passe de 8 caractères sera généré pour ${widget.managerName ?? 'ce gestionnaire'}. Son ancien mot de passe ne fonctionnera plus et ses sessions seront déconnectées. Les autres comptes restent inchangés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remplacer et mémoriser'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (accepted == true) await _action(regenerate: true);
  }

  Future<void> _action({bool forget = false, bool regenerate = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      if (regenerate) {
        await widget.access.regenerate();
      } else if (forget) {
        await widget.access.forget();
      } else {
        final text = await widget.access.copyText(widget.groupName);
        if (!mounted || !widget.access.allowed) return;
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) {
          if (manager) {
            setState(() => notice = 'Accès copiés');
          } else {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Accès copiés')));
          }
        }
      }
    } on Object catch (failure) {
      if (mounted) setState(() => error = _message(failure));
    } finally {
      await _load();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.access.allowed) return const SizedBox.shrink();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            manager
                ? 'Accès de ${widget.managerName ?? 'ce gestionnaire'}'
                : 'Accès des membres',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            manager
                ? 'Partagez l’accès personnel de ce gestionnaire. Ses permissions suivent les rôles attribués.'
                : 'Partagez l’accès commun en lecture seule à votre groupe.',
          ),
          const SizedBox(height: 12),
          if (saved) ...[
            const Text('Mot de passe mémorisé sur cet appareil'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy ? null : _action,
              child: const Text('Copier les accès'),
            ),
          ],
          TextButton(
            onPressed: busy ? null : _edit,
            child: Text(
              saved
                  ? 'Vérifier un autre mot de passe'
                  : manager
                  ? 'Renseigner le mot de passe existant'
                  : 'Renseigner le mot de passe commun',
            ),
          ),
          if (manager &&
              widget.access.managerAccountId != widget.access.service.accountId)
            TextButton(
              onPressed: busy ? null : _regenerate,
              child: const Text('Générer un nouveau mot de passe'),
            ),
          if (saved)
            TextButton(
              onPressed: busy ? null : () => _action(forget: true),
              child: const Text('Oublier sur cet appareil'),
            ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (notice != null) Semantics(liveRegion: true, child: Text(notice!)),
        ],
      ),
    );
  }
}
