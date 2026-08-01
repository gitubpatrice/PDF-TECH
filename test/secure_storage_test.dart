import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_tech/services/secure_app_preferences.dart';
import 'package:pdf_tech/services/secure_storage_service.dart';

void main() {
  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('SecureStorageService', () {
    test('readString retourne null quand la cle n\'existe pas', () async {
      final value = await SecureStorageService.readString('missing_key');
      expect(value, isNull);
    });

    test('writeString / readString fonctionnent', () async {
      const key = 'test_string';
      const value = 'sensitive_value';
      await SecureStorageService.writeString(key, value);
      final read = await SecureStorageService.readString(key);
      expect(read, value);
    });

    test('writeBool / readBool fonctionnent', () async {
      const key = 'test_bool';
      await SecureStorageService.writeBool(key, true);
      expect(await SecureStorageService.readBool(key), true);
      await SecureStorageService.writeBool(key, false);
      expect(await SecureStorageService.readBool(key), false);
    });

    test('writeInt / readInt fonctionnent', () async {
      const key = 'test_int';
      await SecureStorageService.writeInt(key, 42);
      expect(await SecureStorageService.readInt(key), 42);
    });

    test('writeStringList / readStringList fonctionnent', () async {
      const key = 'test_list';
      final value = ['a', 'b', 'c'];
      await SecureStorageService.writeStringList(key, value);
      expect(await SecureStorageService.readStringList(key), value);
    });

    test('remove supprime une cle', () async {
      const key = 'test_remove';
      await SecureStorageService.writeString(key, 'value');
      await SecureStorageService.remove(key);
      expect(await SecureStorageService.readString(key), isNull);
    });
  });

  group('SecureAppPreferences', () {
    test('full storage mode par defaut est false', () async {
      await SecureAppPreferences.setFullStorageMode(false);
      expect(await SecureAppPreferences.getFullStorageMode(), false);
    });

    test('full storage mode peut etre active', () async {
      await SecureAppPreferences.setFullStorageMode(true);
      expect(await SecureAppPreferences.getFullStorageMode(), true);
      await SecureAppPreferences.setFullStorageMode(false);
    });
  });
}
