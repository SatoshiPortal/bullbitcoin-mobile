import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/keychain_locked_exception.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';
import 'package:bb_mobile/features/pin_code/domain/pin_code_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockKeyValueStorage extends Mock
    implements KeyValueStorageDatasource<String> {}

void main() {
  test('maps a locked keychain to PinCodeKeychainLockedFailure', () async {
    final storage = MockKeyValueStorage();
    when(
      () => storage.getValue(any()),
    ).thenThrow(const KeychainLockedException());
    final repository = PinCodeRepository(storage);

    final result = await repository.isPinCodeSet();

    expect(result, isA<Err<bool, PinCodeFailure>>());
    expect((result as Err).failure, isA<PinCodeKeychainLockedFailure>());
  });
}
