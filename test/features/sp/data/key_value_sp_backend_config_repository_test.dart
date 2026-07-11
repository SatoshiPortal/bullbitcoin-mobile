import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/data/key_value_sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/entities/backend_kind.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryStorage implements KeyValueStorageDatasource<String> {
  final Map<String, String> _store = {};

  @override
  Future<void> saveValue({required String key, required String value}) async =>
      _store[key] = value;

  @override
  Future<Map<String, String>> getAll() async => Map.of(_store);

  @override
  Future<String?> getValue(String key) async => _store[key];

  @override
  Future<bool> hasValue(String key) async => _store.containsKey(key);

  @override
  Future<void> deleteValue(String key) async => _store.remove(key);

  @override
  Future<void> deleteAll() async => _store.clear();
}

void main() {
  group('KeyValueSpBackendConfigRepository.testBackend', () {
    KeyValueSpBackendConfigRepository build({
      Future<int> Function({required String url})? testBlindbit,
      Future<void> Function({required String url})? testElectrum,
    }) => KeyValueSpBackendConfigRepository(
      storage: _InMemoryStorage(),
      testBlindbit: testBlindbit ?? ({required String url}) async => 0,
      testElectrum: testElectrum ?? ({required String url}) async {},
    );

    test('blindbit returns Ok on success', () async {
      final repo = build(testBlindbit: ({required String url}) async => 42);
      final result = await repo.testBackend(BackendKind.blindbit, 'http://ok');
      expect(result, isA<Ok<void, SpFailure>>());
    });

    test('blindbit maps a throw to SpBackendUnreachable', () async {
      final repo = build(
        testBlindbit: ({required String url}) async => throw Exception('boom'),
      );
      final result = await repo.testBackend(BackendKind.blindbit, 'http://bad');
      expect(result, isA<Err<void, SpFailure>>());
      final failure = (result as Err<void, SpFailure>).failure;
      expect(failure, isA<SpBackendUnreachable>());
      expect(failure.logMessage, contains('boom'));
    });

    test('electrum returns Ok on success', () async {
      final repo = build(testElectrum: ({required String url}) async {});
      final result = await repo.testBackend(BackendKind.electrum, 'tcp://ok:1');
      expect(result, isA<Ok<void, SpFailure>>());
    });

    test('electrum maps a throw to SpBackendUnreachable', () async {
      final repo = build(
        testElectrum: ({required String url}) async =>
            throw Exception('no route'),
      );
      final result = await repo.testBackend(BackendKind.electrum, 'tcp://bad:1');
      expect(result, isA<Err<void, SpFailure>>());
      final failure = (result as Err<void, SpFailure>).failure;
      expect(failure, isA<SpBackendUnreachable>());
      expect(failure.logMessage, contains('no route'));
    });
  });
}
