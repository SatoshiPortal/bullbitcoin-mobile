import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_startup/data/shared_preferences_startup_storage_repository.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Result<bool, AppStartupFailure>> check({bool isAndroid = true}) =>
      SharedPreferencesStartupStorageRepository(
        isAndroid: isAndroid,
      ).requiresLegacyRestore();

  test(
    'requires restoration for the retired Android storage generation',
    () async {
      SharedPreferences.setMockInitialValues({
        'seed_store_type': '{"storageLibrary":"fss9"}',
      });

      expect(
        await check(),
        isA<Ok<bool, AppStartupFailure>>().having(
          (result) => result.value,
          'requires restore',
          isTrue,
        ),
      );
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString('seed_store_type'),
        '{"storageLibrary":"fss9"}',
      );
    },
  );

  test('accepts the current Android storage generation', () async {
    SharedPreferences.setMockInitialValues({
      'seed_store_type': '{"storageLibrary":"fss10"}',
    });

    expect(
      await check(),
      isA<Ok<bool, AppStartupFailure>>().having(
        (result) => result.value,
        'requires restore',
        isFalse,
      ),
    );
  });

  test('accepts an install without a storage-generation marker', () async {
    SharedPreferences.setMockInitialValues({});

    expect(
      await check(),
      isA<Ok<bool, AppStartupFailure>>().having(
        (result) => result.value,
        'requires restore',
        isFalse,
      ),
    );
  });

  test('ignores the Android marker on other platforms', () async {
    SharedPreferences.setMockInitialValues({'seed_store_type': 'invalid'});

    expect(
      await check(isAndroid: false),
      isA<Ok<bool, AppStartupFailure>>().having(
        (result) => result.value,
        'requires restore',
        isFalse,
      ),
    );
  });

  for (final marker in <Object>[
    '',
    'not json',
    'null',
    '[]',
    '{}',
    '{"storageLibrary":null}',
    '{"storageLibrary":"unknown"}',
    9,
  ]) {
    test('fails closed for invalid marker $marker', () async {
      SharedPreferences.setMockInitialValues({'seed_store_type': marker});

      expect(
        await check(),
        isA<Err<bool, AppStartupFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<AppStartupWalletCheckFailure>(),
        ),
      );
    });
  }
}
