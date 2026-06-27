import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_unlock/data/repositories/failed_unlock_attempts_repository_impl.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockKeyValueStorage extends Mock
    implements KeyValueStorageDatasource<String> {}

void main() {
  late MockKeyValueStorage storage;
  late FailedUnlockAttemptsRepository repository;

  setUp(() {
    storage = MockKeyValueStorage();
    repository = FailedUnlockAttemptsRepository(storage);
  });

  group('getFailedUnlockAttempts', () {
    test('returns Ok with parsed int when storage has a value', () async {
      when(() => storage.getValue(any())).thenAnswer((_) async => '3');

      final result = await repository.getFailedUnlockAttempts();

      expect(result, isA<Ok<int, AppUnlockFailure>>());
      expect((result as Ok).value, 3);
    });

    test('returns Ok(0) when storage has no value', () async {
      when(() => storage.getValue(any())).thenAnswer((_) async => null);

      final result = await repository.getFailedUnlockAttempts();

      expect(result, isA<Ok<int, AppUnlockFailure>>());
      expect((result as Ok).value, 0);
    });

    test('returns Err(AppUnlockUnexpectedFailure) when storage throws', () async {
      when(() => storage.getValue(any())).thenThrow(Exception('storage error'));

      final result = await repository.getFailedUnlockAttempts();

      expect(result, isA<Err<int, AppUnlockFailure>>());
      expect((result as Err).failure, isA<AppUnlockUnexpectedFailure>());
    });
  });

  group('setFailedUnlockAttempts', () {
    test('returns Ok when storage saves successfully', () async {
      when(
        () => storage.saveValue(key: any(named: 'key'), value: any(named: 'value')),
      ).thenAnswer((_) async {});

      final result = await repository.setFailedUnlockAttempts(3);

      expect(result, isA<Ok<void, AppUnlockFailure>>());
    });

    test('returns Err(AppUnlockUnexpectedFailure) when storage throws', () async {
      when(
        () => storage.saveValue(key: any(named: 'key'), value: any(named: 'value')),
      ).thenThrow(Exception('storage error'));

      final result = await repository.setFailedUnlockAttempts(3);

      expect(result, isA<Err<void, AppUnlockFailure>>());
      expect((result as Err).failure, isA<AppUnlockUnexpectedFailure>());
    });
  });
}
