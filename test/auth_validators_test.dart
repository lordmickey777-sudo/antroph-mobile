import 'package:flutter_test/flutter_test.dart';
import 'package:antroph_mobile/core/auth/validation/auth_validators.dart';

void main() {
  group('AuthValidators.email', () {
    test('rejects empty', () {
      expect(AuthValidators.email(''), isNotNull);
    });
    test('rejects invalid', () {
      expect(AuthValidators.email('foo'), isNotNull);
      expect(AuthValidators.email('foo@bar'), isNotNull);
      expect(AuthValidators.email('foo@bar.'), isNotNull);
    });
    test('accepts valid', () {
      expect(AuthValidators.email('user@example.com'), isNull);
    });
  });

  group('AuthValidators.resetToken', () {
    test('rejects empty or non-6 digits', () {
      expect(AuthValidators.resetToken(''), isNotNull);
      expect(AuthValidators.resetToken('12345'), isNotNull);
      expect(AuthValidators.resetToken('1234567'), isNotNull);
      expect(AuthValidators.resetToken('12a456'), isNotNull);
    });
    test('accepts exactly 6 digits', () {
      expect(AuthValidators.resetToken('012345'), isNull);
    });
  });

  group('AuthValidators.newPassword', () {
    test('rejects short', () {
      expect(AuthValidators.newPassword('Abc12'), isNotNull);
    });
    test('rejects missing number or letter', () {
      expect(AuthValidators.newPassword('abcdefgh'), isNotNull);
      expect(AuthValidators.newPassword('12345678'), isNotNull);
    });
    test('accepts strong enough', () {
      expect(AuthValidators.newPassword('Abcdef12'), isNull);
    });
  });
}
