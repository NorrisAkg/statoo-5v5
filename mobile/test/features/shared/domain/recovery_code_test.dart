import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/features/shared/domain/recovery_code.dart';

void main() {
  group('RecoveryCode', () {
    group('RecoveryCodeGenerator.generate()', () {
      test('G-W-T 1.1: generates code with format XXXX-XXXX-XXXX-XXXX (16 chars Crockford, 3 dashes)', () {
        // Given / When
        final String code = RecoveryCodeGenerator.generate();

        // Then
        expect(code.length, equals(19));
        final RegExp formatRegex = RegExp(
          r'^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{4}-[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{4}-[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{4}-[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{4}$',
        );
        expect(formatRegex.hasMatch(code), isTrue, reason: 'Generated code $code must match Crockford 4x4 format');
      });

      test('G-W-T 1.2: excludes ambiguous characters 0, O, 1, I across multiple generations', () {
        // Given
        const String excluded = '0O1IoIlL';

        // When
        for (int i = 0; i < 200; i++) {
          final String code = RecoveryCodeGenerator.generate();

          // Then
          for (final int rune in excluded.runes) {
            final String char = String.fromCharCode(rune);
            expect(
              code.contains(char),
              isFalse,
              reason: 'Code $code should never contain ambiguous character "$char"',
            );
          }
        }
      });

      test('G-W-T 1.3: two consecutive generations are never identical (secure randomness)', () {
        // Given / When
        final String first = RecoveryCodeGenerator.generate();
        final String second = RecoveryCodeGenerator.generate();

        // Then
        expect(first, isNot(equals(second)));
      });

      test('G-W-T 1.4: generates unique codes with zero collision in a batch of 100', () {
        // Given
        final Set<String> generatedCodes = <String>{};
        const int batchSize = 100;

        // When
        for (int i = 0; i < batchSize; i++) {
          final String code = RecoveryCodeGenerator.generate();
          generatedCodes.add(code);
        }

        // Then
        expect(generatedCodes.length, equals(batchSize));
      });

      test('G-W-T 1.5: generated code can be normalized and validated successfully', () {
        // Given
        final String rawCode = RecoveryCodeGenerator.generate();

        // When
        final String normalized = RecoveryCode.normalize(rawCode);

        // Then
        expect(normalized.length, equals(16));
        expect(RecoveryCode.isValid(normalized), isTrue);
        expect(RecoveryCode.format(normalized), equals(rawCode));
      });
    });

    group('RecoveryCode.normalize()', () {
      test('G-W-T 2.1: strips dashes and converts lowercase to uppercase', () {
        // Given
        const String raw = '2345-6789-abcd-efgh';

        // When
        final String normalized = RecoveryCode.normalize(raw);

        // Then
        expect(normalized, equals('23456789ABCDEFGH'));
      });

      test('G-W-T 2.2: strips standard spaces at edges and between segments', () {
        // Given
        const String raw = '  2345 - 6789  - ABCD - efgh  ';

        // When
        final String normalized = RecoveryCode.normalize(raw);

        // Then
        expect(normalized, equals('23456789ABCDEFGH'));
      });

      test('G-W-T 2.3: strips multiple non-standard spacing and dash variants (tabs, newlines, en/em dashes)', () {
        // Given
        const String raw = '\t2345\n–\r6789\u00A0—\tABCD  EFGH\n';

        // When
        final String normalized = RecoveryCode.normalize(raw);

        // Then
        expect(normalized, equals('23456789ABCDEFGH'));
      });

      test('G-W-T 2.4: returns empty string when input is empty or contains only delimiters', () {
        // Given / When / Then
        expect(RecoveryCode.normalize(''), equals(''));
        expect(RecoveryCode.normalize('   '), equals(''));
        expect(RecoveryCode.normalize('---'), equals(''));
        expect(RecoveryCode.normalize(' - - - \t \n '), equals(''));
      });

      test('G-W-T 2.5: is idempotent (normalize(normalize(x)) == normalize(x))', () {
        // Given
        const String raw = '  2345-6789-jkmn-pqrs  ';

        // When
        final String firstPass = RecoveryCode.normalize(raw);
        final String secondPass = RecoveryCode.normalize(firstPass);

        // Then
        expect(secondPass, equals(firstPass));
        expect(secondPass, equals('23456789JKMNPQRS'));
      });
    });

    group('RecoveryCode.isValid()', () {
      test('G-W-T 3.1: validates a nominal normalized code of 16 Crockford characters', () {
        // Given
        const String code = '23456789ABCDEFGH';

        // When / Then
        expect(RecoveryCode.isValid(code), isTrue);
      });

      test('G-W-T 3.2: validates a code with maximum allowed length of 64 Crockford characters', () {
        // Given (64 Crockford chars: '23456789ABCDEFGH' * 4)
        final String code = '23456789ABCDEFGH' * 4;
        expect(code.length, equals(64));

        // When / Then
        expect(RecoveryCode.isValid(code), isTrue);
      });

      test('G-W-T 3.3: validates intermediate lengths between 16 and 64 characters', () {
        // Given / When / Then
        expect(RecoveryCode.isValid('23456789ABCDEFGHJKLM'), isTrue); // 20
        expect(RecoveryCode.isValid('23456789ABCDEFGH' * 2), isTrue); // 32
        expect(RecoveryCode.isValid('23456789ABCDEFGH' * 3), isTrue); // 48
      });

      test('G-W-T 3.4: rejects codes shorter than 16 characters', () {
        // Given
        const String short15 = '23456789ABCDEFG'; // 15
        const String short8 = '23456789';
        const String empty = '';

        // When / Then
        expect(RecoveryCode.isValid(short15), isFalse);
        expect(RecoveryCode.isValid(short8), isFalse);
        expect(RecoveryCode.isValid(empty), isFalse);
      });

      test('G-W-T 3.5: rejects codes longer than 64 characters', () {
        // Given (65 Crockford chars)
        final String long65 = '${'23456789ABCDEFGH' * 4}2';
        expect(long65.length, equals(65));

        // When / Then
        expect(RecoveryCode.isValid(long65), isFalse);
      });

      test('G-W-T 3.6: rejects codes containing ambiguous characters 0, O, 1, I', () {
        // Given
        const String withZero = '23456789ABCDEFG0';
        const String withO = '23456789ABCDEFGO';
        const String withOne = '23456789ABCDEFG1';
        const String withI = '23456789ABCDEFGI';

        // When / Then
        expect(RecoveryCode.isValid(withZero), isFalse);
        expect(RecoveryCode.isValid(withO), isFalse);
        expect(RecoveryCode.isValid(withOne), isFalse);
        expect(RecoveryCode.isValid(withI), isFalse);
      });

      test('G-W-T 3.7: rejects codes containing special characters, symbols, or unnormalized dashes', () {
        // Given
        const String withBang = '23456789ABCDEFG!';
        const String withAt = '23456789ABCDEFG@';
        const String withDashes = '2345-6789-ABCD-EFGH';
        const String withSpace = '23456789 ABCDEFGH';

        // When / Then
        expect(RecoveryCode.isValid(withBang), isFalse);
        expect(RecoveryCode.isValid(withAt), isFalse);
        expect(RecoveryCode.isValid(withDashes), isFalse);
        expect(RecoveryCode.isValid(withSpace), isFalse);
      });

      test('G-W-T 3.8: rejects codes with control characters or whitespace', () {
        // Given
        const String withNull = '23456789ABCDEFG\x00';
        const String withEsc = '23456789ABCDEFG\x1B';
        const String withDel = '23456789ABCDEFG\x7F';
        const String withNewline = '23456789ABCDEFG\n';

        // When / Then
        expect(RecoveryCode.isValid(withNull), isFalse);
        expect(RecoveryCode.isValid(withEsc), isFalse);
        expect(RecoveryCode.isValid(withDel), isFalse);
        expect(RecoveryCode.isValid(withNewline), isFalse);
      });

      test('G-W-T 3.9: rejects unicode accented characters or emojis', () {
        // Given
        const String withAccent = '23456789ABCDEFGÉ';
        const String withEmoji = '23456789ABCDEFG⚽';

        // When / Then
        expect(RecoveryCode.isValid(withAccent), isFalse);
        expect(RecoveryCode.isValid(withEmoji), isFalse);
      });
    });

    group('RecoveryCode.format()', () {
      test('G-W-T 4.1: formats a nominal 16-character code with dashes every 4 chars', () {
        // Given
        const String normalized = '23456789ABCDEFGH';

        // When
        final String formatted = RecoveryCode.format(normalized);

        // Then
        expect(formatted, equals('2345-6789-ABCD-EFGH'));
      });

      test('G-W-T 4.2: formats a 20-character code into 5 groups of 4', () {
        // Given
        const String normalized = '23456789ABCDEFGHJKLM';

        // When
        final String formatted = RecoveryCode.format(normalized);

        // Then
        expect(formatted, equals('2345-6789-ABCD-EFGH-JKLM'));
      });

      test('G-W-T 4.3: formats a code whose length is not a multiple of 4 with a final remainder group', () {
        // Given (18 characters)
        const String normalized = '23456789ABCDEFGHJK';

        // When
        final String formatted = RecoveryCode.format(normalized);

        // Then
        expect(formatted, equals('2345-6789-ABCD-EFGH-JK'));
      });

      test('G-W-T 4.4: returns short or empty string unchanged without trailing dashes', () {
        // Given / When / Then
        expect(RecoveryCode.format(''), equals(''));
        expect(RecoveryCode.format('2'), equals('2'));
        expect(RecoveryCode.format('23'), equals('23'));
        expect(RecoveryCode.format('234'), equals('234'));
        expect(RecoveryCode.format('2345'), equals('2345'));
      });

      test('G-W-T 4.5: roundtrip format and normalize preserves normalized code', () {
        // Given
        const String original = '23456789ABCDEFGH';

        // When
        final String roundtrip = RecoveryCode.normalize(RecoveryCode.format(original));

        // Then
        expect(roundtrip, equals(original));
      });
    });
  });
}
