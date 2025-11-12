import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:antroph_mobile/core/auth/services/email_storage_service.dart';

void main() {
  group('EmailStorageService', () {
    setUp(() {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    test('should save and retrieve last email', () async {
      const testEmail = 'test@example.com';

      // Save email
      await EmailStorageService.saveLastEmail(testEmail);

      // Retrieve email
      final retrievedEmail = await EmailStorageService.getLastEmail();

      expect(retrievedEmail, equals(testEmail));
    });

    test('should return null when no email is stored', () async {
      final retrievedEmail = await EmailStorageService.getLastEmail();
      expect(retrievedEmail, isNull);
    });

    test('should clear last email', () async {
      const testEmail = 'test@example.com';

      // Save email
      await EmailStorageService.saveLastEmail(testEmail);

      // Verify it's saved
      expect(await EmailStorageService.getLastEmail(), equals(testEmail));

      // Clear email
      await EmailStorageService.clearLastEmail();

      // Verify it's cleared
      expect(await EmailStorageService.getLastEmail(), isNull);
    });

    test('should trim email when saving', () async {
      const testEmailWithSpaces = '  test@example.com  ';
      const expectedEmail = 'test@example.com';

      await EmailStorageService.saveLastEmail(testEmailWithSpaces);
      final retrievedEmail = await EmailStorageService.getLastEmail();

      expect(retrievedEmail, equals(expectedEmail));
    });
  });
}
