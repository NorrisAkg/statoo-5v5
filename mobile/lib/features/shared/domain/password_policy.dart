/// Represents the result of validating a password against domain policy rules.
class PasswordValidationResult {
  /// Creates a [PasswordValidationResult] with explicit rule outcomes.
  const PasswordValidationResult({
    required this.hasMinLength,
    required this.hasMaxLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
    required this.isNotUsername,
    required this.hasNoControlChars,
  });

  /// Whether the password satisfies the minimum length requirement.
  final bool hasMinLength;

  /// Whether the password satisfies the maximum length requirement.
  final bool hasMaxLength;

  /// Whether the password contains at least one uppercase letter.
  final bool hasUppercase;

  /// Whether the password contains at least one lowercase letter.
  final bool hasLowercase;

  /// Whether the password contains at least one digit.
  final bool hasDigit;

  /// Whether the password is not identical to the username (ignoring case and whitespace).
  final bool isNotUsername;

  /// Whether the password is free from control characters (ASCII < 32 or == 127).
  final bool hasNoControlChars;

  /// Whether all validation criteria are satisfied.
  bool get isValid =>
      hasMinLength &&
      hasMaxLength &&
      hasUppercase &&
      hasLowercase &&
      hasDigit &&
      isNotUsername &&
      hasNoControlChars;

  @override
  String toString() =>
      'PasswordValidationResult(isValid: $isValid, hasMinLength: $hasMinLength, '
      'hasMaxLength: $hasMaxLength, hasUppercase: $hasUppercase, '
      'hasLowercase: $hasLowercase, hasDigit: $hasDigit, '
      'isNotUsername: $isNotUsername, hasNoControlChars: $hasNoControlChars)';
}

/// Pure domain policy enforcing password complexity and security constraints.
class PasswordPolicy {
  const PasswordPolicy._();

  /// Minimum required password length.
  static const int minLength = 8;

  /// Maximum allowed password length.
  static const int maxLength = 200;

  static final RegExp _uppercaseRegex = RegExp('[A-Z]');
  static final RegExp _lowercaseRegex = RegExp('[a-z]');
  static final RegExp _digitRegex = RegExp('[0-9]');
  static final RegExp _whitespaceRegex = RegExp(r'\s+');

  /// Validates [password] against domain policy constraints, optionally verifying
  /// that it does not match [username].
  static PasswordValidationResult validate(
    String password, {
    String? username,
  }) {
    final bool hasMinLength = password.length >= minLength;
    final bool hasMaxLength = password.length <= maxLength;
    final bool hasUppercase = _uppercaseRegex.hasMatch(password);
    final bool hasLowercase = _lowercaseRegex.hasMatch(password);
    final bool hasDigit = _digitRegex.hasMatch(password);

    final bool hasNoControlChars = !password.runes.any(
      (rune) => rune < 32 || rune == 127,
    );

    final bool isNotUsername;
    if (username == null || username.trim().isEmpty) {
      isNotUsername = true;
    } else {
      final String cleanPassword = password
          .replaceAll(_whitespaceRegex, '')
          .toLowerCase();
      final String cleanUsername = username
          .replaceAll(_whitespaceRegex, '')
          .toLowerCase();
      isNotUsername = cleanPassword != cleanUsername;
    }

    return PasswordValidationResult(
      hasMinLength: hasMinLength,
      hasMaxLength: hasMaxLength,
      hasUppercase: hasUppercase,
      hasLowercase: hasLowercase,
      hasDigit: hasDigit,
      isNotUsername: isNotUsername,
      hasNoControlChars: hasNoControlChars,
    );
  }
}
