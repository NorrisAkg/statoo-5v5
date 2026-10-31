import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/features/shared/domain/password_policy.dart';

void main() {
  group('PasswordPolicy', () {
    group('PasswordPolicy.validate() - Nominal scenarios', () {
      test('G-W-T 1.1: validates a standard compliant password with username provided', () {
        // Given
        const String password = 'Secret123!';
        const String username = 'alex';

        // When
        final PasswordValidationResult result = PasswordPolicy.validate(password, username: username);

        // Then
        expect(result.isValid, isTrue);
        expect(result.hasMinLength, isTrue);
        expect(result.hasUppercase, isTrue);
        expect(result.hasLowercase, isTrue);
        expect(result.hasDigit, isTrue);
        expect(result.isNotUsername, isTrue);
        expect(result.hasNoControlChars, isTrue);
      });

      test('G-W-T 1.2: validates a password at exactly minimum length (8 chars)', () {
        // Given
        const String password = 'Abcdef1!';

        // When
        final PasswordValidationResult result = PasswordPolicy.validate(password);

        // Then
        expect(result.isValid, isTrue);
        expect(result.hasMinLength, isTrue);
      });

      test('G-W-T 1.3: validates a password at exactly maximum length (200 chars)', () {
        // Given (200 chars containing lowercase, uppercase, digits)
        final String exact200 = '${'Aa1' * 66}B2';
        expect(exact200.length, equals(200));

        // When
        final PasswordValidationResult result = PasswordPolicy.validate(exact200);

        // Then
        expect(result.isValid, isTrue);
        expect(result.hasMinLength, isTrue);
      });

      test('G-W-T 1.4: allows internal printable spaces if other criteria are satisfied', () {
        // Given
        const String password = 'Mon Super Mot De Passe 2026';

        // When
        final PasswordValidationResult result = PasswordPolicy.validate(password);

        // Then
        expect(result.isValid, isTrue);
        expect(result.hasNoControlChars, isTrue);
      });

      test('G-W-T 1.5: allows varied special printable symbols', () {
        // Given
        const String password = r'P@$$w0rd!#%&*()-_=+[{]};:,.<>/?~';

        // When
        final PasswordValidationResult result = PasswordPolicy.validate(password);

        // Then
        expect(result.isValid, isTrue);
      });
    });

    group('PasswordPolicy.validate() - Length boundaries', () {
      test('G-W-T 2.1: rejects password shorter than 8 characters (7 chars)', () {
        // Given
        const String password = 'Abcde1!'; // 7 chars

        // When
        final PasswordValidationResult result = PasswordPolicy.validate(password);

        // Then
        expect(result.isValid, isFalse);
        expect(result.hasMinLength, isFalse);
        expect(result.hasUppercase, isTrue);
        expect(result.hasLowercase, isTrue);
        expect(result.hasDigit, isTrue);
      });

      test('G-W-T 2.2: rejects empty string', () {
        // Given
        const String password = '';

        // When
        final PasswordValidationResult result = PasswordPolicy.validate(password);

        // Then
        expect(result.isValid, isFalse);
        expect(result.hasMinLength, isFalse);
        expect(result.hasUppercase, isFalse);
        expect(result.hasLowercase, isFalse);
        expect(result.hasDigit, isFalse);
      });

      test('G-W-T 2.3: rejects password longer than 200 characters (201 chars)', () {
        // Given
        final String password201 = 'Aa1' * 67; // 201 chars
        expect(password201.length, equals(201));

        // When
        final PasswordValidationResult result = PasswordPolicy.validate(password201);

        // Then
        expect(result.isValid, isFalse);
      });
    });

    group('PasswordPolicy.validate() - Character complexity', () {
      test('G-W-T 3.1: rejects when lowercase letter is missing', () {
        // Given
        const String password = 'ABCDEFGH1!';

        // When
        final PasswordValidationResult result = PasswordPolicy.validate(password);

        // Then
        expect(result.isValid, isFalse);
        expect(result.hasLowercase, isFalse);
        expect(result.hasUppercase, isTrue);
        expect(result.hasDigit, isTrue);
      });

      test('G-W-T 3.2: rejects when uppercase letter is missing', () {
        // Given
        const String password = 'abcdefgh1!';

        // When
        final PasswordValidationResult result = PasswordPolicy.validate(password);

        // Then
        expect(result.isValid, isFalse);
        expect(result.hasUppercase, isFalse);
        expect(result.hasLowercase, isTrue);
        expect(result.hasDigit, isTrue);
      });

      test('G-W-T 3.3: rejects when digit is missing', () {
        // Given
        const String password = 'Abcdefgh!';

        // When
        final PasswordValidationResult result = PasswordPolicy.validate(password);

        // Then
        expect(result.isValid, isFalse);
        expect(result.hasDigit, isFalse);
        expect(result.hasUppercase, isTrue);
        expect(result.hasLowercase, isTrue);
      });

      test('G-W-T 3.4: rejects when only digits are present', () {
        // Given
        const String password = '1234567890';

        // When
        final PasswordValidationResult result = PasswordPolicy.validate(password);

        // Then
        expect(result.isValid, isFalse);
        expect(result.hasDigit, isTrue);
        expect(result.hasLowercase, isFalse);
        expect(result.hasUppercase, isFalse);
      });

      test('G-W-T 3.5: rejects when only letters are present without digits', () {
        // Given
        const String password = 'Abcdefghijkl';

        // When
        final PasswordValidationResult result = PasswordPolicy.validate(password);

        // Then
        expect(result.isValid, isFalse);
        expect(result.hasDigit, isFalse);
        expect(result.hasUppercase, isTrue);
        expect(result.hasLowercase, isTrue);
      });
    });

    group('PasswordPolicy.validate() - Control characters and security', () {
      test(r'G-W-T 4.1: rejects null byte (\x00)', () {
        // Given
        const String password = 'Secret123!\x00';

        // When
        final PasswordValidationResult result = PasswordPolicy.validate(password);

        // Then
        expect(result.isValid, isFalse);
        expect(result.hasNoControlChars, isFalse);
      });

      test(r'G-W-T 4.2: rejects escape control byte (\x1B)', () {
        // Given
        const String password = 'Secret123!\x1B';

        // When
        final PasswordValidationResult result = PasswordPolicy.validate(password);

        // Then
        expect(result.isValid, isFalse);
        expect(result.hasNoControlChars, isFalse);
      });

      test(r'G-W-T 4.3: rejects delete control byte (\x7F)', () {
        // Given
        const String password = 'Secret123!\x7F';

        // When
        final PasswordValidationResult result = PasswordPolicy.validate(password);

        // Then
        expect(result.isValid, isFalse);
        expect(result.hasNoControlChars, isFalse);
      });

      test(r'G-W-T 4.4: rejects low ASCII control codes (< 32, e.g. \x01, \x08)', () {
        // Given
        const String passwordSoh = 'Secret123!\x01';
        const String passwordBs = 'Secret123!\x08';

        // When
        final PasswordValidationResult resSoh = PasswordPolicy.validate(passwordSoh);
        final PasswordValidationResult resBs = PasswordPolicy.validate(passwordBs);

        // Then
        expect(resSoh.isValid, isFalse);
        expect(resSoh.hasNoControlChars, isFalse);
        expect(resBs.isValid, isFalse);
        expect(resBs.hasNoControlChars, isFalse);
      });
    });

    group('PasswordPolicy.validate() - Username collision', () {
      test('G-W-T 5.1: rejects password identical to username (exact match)', () {
        // Given
        const String username = 'Captain2026';
        const String password = 'Captain2026';

        // When
        final PasswordValidationResult result = PasswordPolicy.validate(password, username: username);

        // Then
        expect(result.isValid, isFalse);
        expect(result.isNotUsername, isFalse);
      });

      test('G-W-T 5.2: rejects password identical to username (case-insensitive)', () {
        // Given
        const String username = 'Captain2026';
        const String password = 'captain2026';

        // When
        final PasswordValidationResult result = PasswordPolicy.validate(password, username: username);

        // Then
        expect(result.isValid, isFalse);
        expect(result.isNotUsername, isFalse);
      });

      test('G-W-T 5.3: rejects password identical to username ignoring whitespace', () {
        // Given
        const String username = '  Captain 2026  ';
        const String password = 'captain2026';

        // When
        final PasswordValidationResult result = PasswordPolicy.validate(password, username: username);

        // Then
        expect(result.isValid, isFalse);
        expect(result.isNotUsername, isFalse);
      });

      test('G-W-T 5.4: rejects password with embedded whitespace matching username', () {
        // Given
        const String username = 'captain2026';
        const String password = ' C a p t a i n 2 0 2 6 ';

        // When
        final PasswordValidationResult result = PasswordPolicy.validate(password, username: username);

        // Then
        expect(result.isValid, isFalse);
        expect(result.isNotUsername, isFalse);
      });

      test('G-W-T 5.5: accepts password containing username as substring if not identical', () {
        // Given
        const String username = 'Alex';
        const String password = 'AlexStrongPassword2026!';

        // When
        final PasswordValidationResult result = PasswordPolicy.validate(password, username: username);

        // Then
        expect(result.isNotUsername, isTrue);
        expect(result.isValid, isTrue);
      });

      test('G-W-T 5.6: considers isNotUsername satisfied when username is null', () {
        // Given
        const String password = 'Secret123!';

        // When
        // ignore: avoid_redundant_argument_values
        final PasswordValidationResult result = PasswordPolicy.validate(password, username: null);

        // Then
        expect(result.isNotUsername, isTrue);
        expect(result.isValid, isTrue);
      });

      test('G-W-T 5.7: considers isNotUsername satisfied when username is empty or whitespace', () {
        // Given
        const String password = 'Secret123!';

        // When
        final PasswordValidationResult resultEmpty = PasswordPolicy.validate(password, username: '');
        final PasswordValidationResult resultSpaces = PasswordPolicy.validate(password, username: '   ');

        // Then
        expect(resultEmpty.isNotUsername, isTrue);
        expect(resultEmpty.isValid, isTrue);
        expect(resultSpaces.isNotUsername, isTrue);
        expect(resultSpaces.isValid, isTrue);
      });
    });

    group('PasswordPolicy - Constants and structure', () {
      test('G-W-T 6.1: exposes correct policy length constraints', () {
        expect(PasswordPolicy.minLength, equals(8));
        expect(PasswordPolicy.maxLength, equals(200));
      });

      test('G-W-T 6.2: PasswordValidationResult toString provides clear diagnostic', () {
        // Given
        final PasswordValidationResult result = PasswordPolicy.validate('weak');

        // When
        final String debugStr = result.toString();

        // Then
        expect(debugStr, contains('isValid: false'));
        expect(debugStr, contains('hasMinLength: false'));
      });
    });
  });
}
