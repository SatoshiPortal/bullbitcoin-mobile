import 'dart:async';

import 'package:bb_mobile/core/exchange/data/exchange_api_key_repository_impl.dart';
import 'package:bb_mobile/core/exchange/domain/entity/exchange_api_key.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

class _Storage extends Fake implements KeyValueStorageDatasource<String> {
  final started = Completer<void>();
  final finish = Completer<void>();
  final values = <String, String>{};
  final operations = <String>[];
  bool failWrite = false;

  @override
  Future<void> saveValue({required String key, required String value}) async {
    started.complete();
    await finish.future;
    if (failWrite) {
      operations.add('failed-write');
      throw Exception('Simulated refusal');
    }
    values[key] = value;
    operations.add('write');
  }

  @override
  Future<void> deleteValue(String key) async {
    values.remove(key);
    operations.add('delete');
  }
}

ExchangeApiKey _credential() => switch (ExchangeApiKey.create(
  id: 'id',
  key: 'synthetic',
  name: 'name',
  userId: 'user',
  isActive: true,
  createdAt: 0,
  updatedAt: 0,
)) {
  Ok(:final value) => value,
  Err() => throw StateError('Invalid synthetic fixture'),
};

void main() {
  for (final failWrite in [false, true]) {
    test(
      'logout wins over a pending ${failWrite ? 'failed' : 'successful'} credential write',
      () async {
        final storage = _Storage()..failWrite = failWrite;
        final repository = ExchangeApiKeyRepositoryImpl(secureStorage: storage);
        final write = repository.saveApiKey(_credential(), isTestnet: true);
        await storage.started.future;
        final deletion = repository.deleteApiKey(isTestnet: true);
        storage.finish.complete();
        final saved = await write;
        final deleted = await deletion;
        expect(
          saved,
          failWrite
              ? isA<Err<void, ExchangeApiKeyFailure>>()
              : isA<Ok<void, ExchangeApiKeyFailure>>(),
        );
        expect(deleted, isA<Ok<void, ExchangeApiKeyFailure>>());
        expect(storage.operations, [
          failWrite ? 'failed-write' : 'write',
          'delete',
        ]);
        expect(
          storage.values,
          isEmpty,
          reason: 'a late save must not restore a session after logout',
        );
      },
    );
  }
}
