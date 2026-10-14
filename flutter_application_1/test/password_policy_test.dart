import 'package:budgetmate/services/password_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requires length and every character class', () {
    expect(passwordValidationKey('Aa1!x'), 'password_min_length');
    expect(passwordValidationKey('Aa1!xy'), isNull);
    expect(passwordValidationKey('Violet river 29!'), isNull);
    expect(passwordValidationKey('VIOLET RIVER 29!'), 'password_lowercase');
    expect(passwordValidationKey('violet river 29!'), 'password_uppercase');
    expect(passwordValidationKey('Violet river abc!'), 'password_digit');
    expect(passwordValidationKey('Violet river 290'), 'password_symbol');
    expect(passwordValidationKey('Violet river 29🌻'), 'password_symbol');
    expect(passwordValidationKey('  Violet river 29!  '), isNull);
  });
  test('blocks common passwords and preserves maximum length', () {
    expect(passwordValidationKey('123456789012345'), 'password_common');
    expect(passwordValidationKey('PasswordPassword'), 'password_common');
    expect(passwordValidationKey(' ' * 15), 'password_common');
    expect(passwordValidationKey('Aa1!' + 'x' * 124), isNull);
    expect(passwordValidationKey('Aa1!' + 'x' * 125), 'password_max_length');
    expect(passwordValidationKey('Aa1!' + '🌻' * 62), isNull);
    expect(passwordValidationKey('Aa1!' + '🌻' * 63), 'password_max_length');
  });
}
