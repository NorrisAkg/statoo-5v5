import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../application/recovery_controller.dart';
import '../domain/password_policy.dart';
import 'widgets/password_complexity_indicator.dart';

class RecoveryRequestSheet extends ConsumerStatefulWidget {
  const RecoveryRequestSheet({
    super.key,
    this.initialGroupId,
    this.initialUsername,
    this.apiUrl,
    this.onSuccess,
  });

  final String? initialGroupId;
  final String? initialUsername;
  final String? apiUrl;
  final void Function(String newCode)? onSuccess;

  @override
  ConsumerState<RecoveryRequestSheet> createState() =>
      _RecoveryRequestSheetState();
}

class _RecoveryRequestSheetState extends ConsumerState<RecoveryRequestSheet> {
  late final TextEditingController _groupController;
  late final TextEditingController _userController;
  late final TextEditingController _codeController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _groupController =
        TextEditingController(text: widget.initialGroupId ?? '');
    _userController =
        TextEditingController(text: widget.initialUsername ?? '');
    _codeController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _groupController.dispose();
    _userController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _localError = null;
    });

    final groupId = _groupController.text.trim();
    final username = _userController.text.trim();
    final recoveryCode = _codeController.text.trim();
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (groupId.isEmpty ||
        username.isEmpty ||
        recoveryCode.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() {
        _localError = 'Veuillez renseigner tous les champs obligatoires.';
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _localError = 'Les mots de passe ne correspondent pas.';
      });
      return;
    }

    final policyResult = PasswordPolicy.validate(
      newPassword,
      username: username,
    );
    if (!policyResult.isValid) {
      setState(() {
        _localError =
            'Le mot de passe ne respecte pas les critères de sécurité.';
      });
      return;
    }

    final success = await ref
        .read(recoveryControllerProvider.notifier)
        .submitRecovery(
          url: widget.apiUrl ??
              const String.fromEnvironment(
                'STATOO_API',
                defaultValue: 'https://statoo-api.onrender.com',
              ),
          groupId: groupId,
          username: username,
          recoveryCode: recoveryCode,
          newPassword: newPassword,
          confirmPassword: confirmPassword,
        );

    if (success && mounted) {
      final newCode =
          ref.read(recoveryControllerProvider).newRecoveryCode ?? '';
      widget.onSuccess?.call(newCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recoveryControllerProvider);
    final displayedError = _localError ?? state.errorMessage;
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
                      Remix.key_line,
                      color: context.colors.primary500,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Récupération d’accès',
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
                  'Utilisez votre code de secours pour réinitialiser le mot de passe de votre compte gestionnaire.',
                  style: TextStyle(
                    color: context.colors.foreground400,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                if (displayedError != null) ...[
                  AppCard(
                    child: Row(
                      children: [
                        Icon(
                          Remix.error_warning_line,
                          color: context.colors.danger,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            displayedError,
                            style: TextStyle(
                              color: context.colors.danger,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildField(
                  controller: _groupController,
                  label: 'Identifiant du groupe',
                  hint: 'Ex. : #00000001',
                  icon: Remix.team_line,
                ),
                const SizedBox(height: 14),
                _buildField(
                  controller: _userController,
                  label: 'Identifiant utilisateur',
                  hint: 'Votre nom d’utilisateur',
                  icon: Remix.user_line,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                _buildField(
                  controller: _codeController,
                  label: 'Code de secours actuel',
                  hint: 'XXXX-XXXX-XXXX-XXXX',
                  icon: Remix.shield_keyhole_line,
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 14),
                _buildField(
                  controller: _newPasswordController,
                  label: 'Nouveau mot de passe',
                  hint: 'Au moins 8 caractères',
                  icon: Remix.lock_line,
                  obscureText: _obscureNewPassword,
                  onChanged: (_) => setState(() {}),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPassword
                          ? Remix.eye_line
                          : Remix.eye_off_line,
                      color: context.colors.foreground400,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureNewPassword = !_obscureNewPassword;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                PasswordComplexityIndicator(
                  password: _newPasswordController.text,
                  username: _userController.text,
                ),
                const SizedBox(height: 14),
                _buildField(
                  controller: _confirmPasswordController,
                  label: 'Confirmation du mot de passe',
                  hint: 'Confirmez le nouveau mot de passe',
                  icon: Remix.lock_line,
                  obscureText: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Remix.eye_line
                          : Remix.eye_off_line,
                      color: context.colors.foreground400,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: state.isLoading
                      ? 'Réinitialisation...'
                      : 'Réinitialiser',
                  icon: Remix.check_line,
                  onPressed: state.isLoading ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextCapitalization textCapitalization = TextCapitalization.none,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.colors.foreground200,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          autocorrect: false,
          style: TextStyle(color: context.colors.foreground50, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: context.colors.foreground400,
              fontSize: 14,
            ),
            filled: true,
            fillColor: context.colors.background800,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.colors.background700),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.colors.background700),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.colors.primary500, width: 2),
            ),
            prefixIcon: Icon(icon, color: context.colors.foreground400, size: 20),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
