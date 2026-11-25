import 'package:exchange/exchange.dart';
import 'package:exchange/setup.dart';

import 'dart:async';

import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';

class _Storage extends FakeSecureStoragePlatform {
  final started = Completer<void>();
  final finish = Completer<void>();
  final operations = <String>[];
  bool failWrite = false;

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    started.complete();
    await finish.future;
    if (failWrite) {
      operations.add('failed-write');
      throw Exception('Simulated refusal');
    }
    entries[key] = value;
    operations.add('write');
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    entries.remove(key);
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
        final storage = _Storage()
          ..install()
          ..failWrite = failWrite;
        final repository = ExchangeCredentials.open(
          Secrets(scratchDirectory: () async => '/tmp').exchangeKeychain,
        );
        final write = repository.saveApiKey(_credential(), isTestnet: true);
        await storage.started.future;
        final deletion = repository.deleteApiKey(isTestnet: true);
        storage.finish.complete();
        final saved = await write;
        final deleted = await deletion;
        expect(
          saved,
          failWrite
              ? isA<Err<void, ExchangeFailure>>()
              : isA<Ok<void, ExchangeFailure>>(),
        );
        expect(deleted, isA<Ok<void, ExchangeFailure>>());
        expect(storage.operations, [
          failWrite ? 'failed-write' : 'write',
          'delete',
        ]);
        expect(
          storage.entries,
          isEmpty,
          reason: 'a late save must not restore a session after logout',
        );
      },
    );
  }
}
