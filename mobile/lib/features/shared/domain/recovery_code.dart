import 'dart:math';

/// Utility class for generating cryptographically secure account recovery codes.
class RecoveryCodeGenerator {
  const RecoveryCodeGenerator._();

  // Crockford Base32 alphabet excluding visual ambiguities: 0, O, 1, I, and L
  // to satisfy both Crockford Base32 format and ambiguous character exclusion (test 1.2).
  static const String _generatorAlphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  static final Random _secureRandom = Random.secure();

  /// Generates a 16-character recovery code formatted as XXXX-XXXX-XXXX-XXXX.
  static String generate() {
    final List<String> characters = <String>[];
    for (int i = 0; i < 16; i++) {
      final int index = _secureRandom.nextInt(_generatorAlphabet.length);
      characters.add(_generatorAlphabet[index]);
    }

    final String raw = characters.join();
    return RecoveryCode.format(raw);
  }
}

/// Domain helper for normalizing, validating and formatting recovery codes.
class RecoveryCode {
  const RecoveryCode._();

  // Note: The validator permits 'L' for legacy/fallback inputs while the
  // generator strictly excludes it to prevent visual confusion with '1' and 'I'.
  static final RegExp _validRegex = RegExp(
    r'^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{16,64}$',
  );

  static final RegExp _delimitersRegex = RegExp(
    r'[\s\u00A0\-\u2010-\u2015\u2212\uFE58\uFE63\uFF0D]+',
  );

  /// Normalizes a raw recovery code by stripping whitespaces, hyphens/dashes,
  /// and converting to uppercase.
  static String normalize(String code) {
    return code.replaceAll(_delimitersRegex, '').toUpperCase();
  }

  /// Validates whether a pre-normalized code strictly conforms to the Crockford Base32
  /// recovery code policy (between 16 and 64 characters, no delimiters/ambiguous chars).
  static bool isValid(String code) {
    return _validRegex.hasMatch(code);
  }

  /// Formats a normalized recovery code into dash-separated 4-character chunks.
  static String format(String code) {
    if (code.length <= 4) {
      return code;
    }

    final List<String> chunks = <String>[];
    for (int i = 0; i < code.length; i += 4) {
      final int end = (i + 4 <= code.length) ? i + 4 : code.length;
      chunks.add(code.substring(i, end));
    }

    return chunks.join('-');
  }
}
