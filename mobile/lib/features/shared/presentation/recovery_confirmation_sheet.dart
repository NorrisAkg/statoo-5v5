import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../application/recovery_controller.dart';

class RecoveryConfirmationSheet extends ConsumerStatefulWidget {
  const RecoveryConfirmationSheet({
    required this.newRecoveryCode,
    super.key,
    this.onCompleted,
  });

  final String newRecoveryCode;
  final VoidCallback? onCompleted;

  @override
  ConsumerState<RecoveryConfirmationSheet> createState() =>
      _RecoveryConfirmationSheetState();
}

class _RecoveryConfirmationSheetState
    extends ConsumerState<RecoveryConfirmationSheet> {
  bool _hasAcknowledged = false;
  bool _copied = false;

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.newRecoveryCode));
    if (mounted) {
      setState(() {
        _copied = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code de secours copié dans le presse-papiers'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _complete() async {
    await ref.read(recoveryControllerProvider.notifier).confirmCodeAndConnect();
    if (mounted) {
      widget.onCompleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recoveryControllerProvider);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.background900,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: 20 + bottomInset,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Remix.shield_check_line,
                      color: context.colors.primary500,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Nouveau code de secours',
                        style: TextStyle(
                          color: context.colors.foreground50,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Remix.close_line),
                      color: context.colors.foreground400,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Votre mot de passe a été mis à jour avec succès. Par mesure de sécurité, votre ancien code de secours a été révoqué. Conservez précieusement ce nouveau code.',
                  style: TextStyle(
                    color: context.colors.foreground400,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.background800,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.colors.background700),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.newRecoveryCode,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.colors.primary500,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _copyToClipboard,
                        icon: Icon(
                          _copied ? Remix.check_line : Remix.file_copy_line,
                          size: 16,
                        ),
                        label: Text(_copied ? 'Code copié !' : 'Copier'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _hasAcknowledged = !_hasAcknowledged;
                    });
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _hasAcknowledged,
                        activeColor: context.colors.primary500,
                        onChanged: (val) {
                          setState(() {
                            _hasAcknowledged = val ?? false;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            "J'ai bien noté mon nouveau code de secours dans un endroit sûr",
                            style: TextStyle(
                              color: context.colors.foreground50,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: state.isLoading
                      ? 'Connexion en cours...'
                      : 'Accéder à mon groupe',
                  icon: Remix.arrow_right_line,
                  onPressed: _hasAcknowledged && !state.isLoading
                      ? _complete
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
