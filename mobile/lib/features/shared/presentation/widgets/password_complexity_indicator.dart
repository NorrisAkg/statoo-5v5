import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/password_policy.dart';

/// Reusable widget displaying real-time password policy validation criteria.
class PasswordComplexityIndicator extends StatelessWidget {
  const PasswordComplexityIndicator({
    required this.password,
    super.key,
    this.username,
  });

  final String password;
  final String? username;

  @override
  Widget build(BuildContext context) {
    final result = PasswordPolicy.validate(password, username: username);
    final hasUsername = username != null && username!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CriterionRow(
          label: 'Au moins 8 caractères',
          isMet: result.hasMinLength,
        ),
        const SizedBox(height: 6),
        _CriterionRow(
          label: 'Au moins une majuscule (A-Z)',
          isMet: result.hasUppercase,
        ),
        const SizedBox(height: 6),
        _CriterionRow(
          label: 'Au moins une minuscule (a-z)',
          isMet: result.hasLowercase,
        ),
        const SizedBox(height: 6),
        _CriterionRow(
          label: 'Au moins un chiffre (0-9)',
          isMet: result.hasDigit,
        ),
        if (hasUsername) ...[
          const SizedBox(height: 6),
          _CriterionRow(
            label: "Différent du nom d'utilisateur",
            isMet: result.isNotUsername,
          ),
        ],
      ],
    );
  }
}

class _CriterionRow extends StatelessWidget {
  const _CriterionRow({
    required this.label,
    required this.isMet,
  });

  final String label;
  final bool isMet;

  @override
  Widget build(BuildContext context) {
    final activeColor = context.colors.primary500;
    final inactiveColor = context.colors.foreground400;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isMet ? Remix.check_line : Remix.close_line,
          size: 16,
          color: isMet ? activeColor : inactiveColor,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isMet ? context.colors.foreground50 : inactiveColor,
            fontWeight: isMet ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
