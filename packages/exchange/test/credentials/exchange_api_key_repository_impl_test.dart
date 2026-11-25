import 'package:exchange/exchange.dart';
import 'package:exchange/setup.dart';
import 'package:exchange/testing.dart';

import 'dart:convert';

import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';

const _key = 'synthetic-credential';
const _fields = {
  'id': 'key-1',
  'key': _key,
  'name': 'mobile',
  'userId': 'user',
  'isActive': true,
  'createdAt': 0,
  'updatedAt': 0,
};

ExchangeApiKey _credential() => switch (ExchangeApiKey.create(
  id: 'key-1',
  key: _key,
  name: 'mobile',
  userId: 'user',
  isActive: true,
  createdAt: 0,
  updatedAt: 0,
)) {
  Ok(:final value) => value,
  Err() => throw StateError('Invalid synthetic fixture'),
};

void main() {
  late InMemoryExchangeCredentialStorage storage;
  late ExchangeCredentials repository;

  setUp(() {
    storage = InMemoryExchangeCredentialStorage();
    repository = ExchangeCredentials.open(storage);
  });

  test('reads selected environment at point of use without caching', () async {
    storage.entries['mainnet'] = jsonEncode(_fields);
    storage.entries['testnet'] = jsonEncode({..._fields, 'key': 'test-only'});
    expect(
      await repository.readActiveApiKey(isTestnet: false),
      isA<Ok<String?, ExchangeFailure>>().having((r) => r.value, 'key', _key),
    );
    expect(
      await repository.readActiveApiKey(isTestnet: true),
      isA<Ok<String?, ExchangeFailure>>().having(
        (r) => r.value,
        'key',
        'test-only',
      ),
    );
    storage.entries['mainnet'] = jsonEncode({..._fields, 'key': 'replacement'});
    expect(
      await repository.readActiveApiKey(isTestnet: false),
      isA<Ok<String?, ExchangeFailure>>().having(
        (r) => r.value,
        'key',
        'replacement',
      ),
    );
    storage.entries.remove('mainnet');
    expect(
      await repository.readActiveApiKey(isTestnet: false),
      isA<Ok<String?, ExchangeFailure>>().having((r) => r.value, 'key', isNull),
    );
    expect(storage.readKeys, ['mainnet', 'testnet', 'mainnet', 'mainnet']);
  });

  test('missing, empty and inactive records are signed out', () async {
    for (final stored in [
      null,
      '',
      jsonEncode({..._fields, 'isActive': false}),
    ]) {
      if (stored == null) {
        storage.entries.clear();
      } else {
        storage.entries['mainnet'] = stored;
      }
      expect(
        await repository.readActiveApiKey(isTestnet: false),
        isA<Ok<String?, ExchangeFailure>>().having(
          (r) => r.value,
          'key',
          isNull,
        ),
      );
    }
  });

  test(
    'authentication ignores metadata and does not add expiry policy',
    () async {
      storage.entries['mainnet'] = jsonEncode({
        'key': _key,
        'isActive': true,
        'createdAt': 'invalid',
        'expiresAt': 0,
      });
      expect(
        await repository.readActiveApiKey(isTestnet: false),
        isA<Ok<String?, ExchangeFailure>>().having((r) => r.value, 'key', _key),
      );
    },
  );

  test(
    'invalid records are a failure without erasing the credential',
    () async {
      for (final record in [
        '{"key":"$_key", broken',
        '[]',
        jsonEncode({'key': '', 'isActive': true}),
        jsonEncode({'key': 4, 'isActive': true}),
        jsonEncode({'key': _key, 'isActive': 'true'}),
      ]) {
        storage.entries['mainnet'] = record;
        final result = await repository.readActiveApiKey(isTestnet: false);
        expect(
          result,
          isA<Err<String?, ExchangeFailure>>().having(
            (r) => r.failure,
            'failure',
            isA<ExchangeApiKeyInvalidFailure>(),
          ),
        );
        expect(storage.entries['mainnet'], record);
      }
    },
  );

  test(
    'storage refusal stays distinct from logout and never echoes its message',
    () async {
      storage.entries['mainnet'] = jsonEncode(_fields);
      storage.scripted.add(Exception('keychain refused $_key'));
      final result = await repository.readActiveApiKey(isTestnet: false);
      expect(
        result,
        isA<Err<String?, ExchangeFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeCredentialReadFailure>(),
        ),
      );
      if (result case Err(:final failure)) {
        expect(failure.logMessage, isNot(contains(_key)));
      }
      expect(storage.entries, contains('mainnet'));
    },
  );

  test('rejects credentials that cannot safely enter an HTTP header', () async {
    for (final key in [
      ' ',
      'synthetic\r\nheader',
      'synthetic\u0000',
      'synthetic\u{1f600}',
    ]) {
      storage.entries['testnet'] = jsonEncode({'key': key, 'isActive': true});
      final result = await repository.readActiveApiKey(isTestnet: true);
      expect(
        result is Err<String?, ExchangeFailure>,
        isTrue,
        reason: 'invalid stored credentials must fail before reaching HTTP',
      );
    }
  });

  test('saves a domain credential in the existing JSON format', () async {
    expect(
      await repository.saveApiKey(_credential(), isTestnet: true),
      isA<Ok<void, ExchangeFailure>>(),
    );
    expect(storage.entries.keys, ['testnet']);
    expect(jsonDecode(storage.entries['testnet'] ?? ''), {
      ..._fields,
      'lastUsedAt': null,
      'expiresAt': null,
    });
  });

  test('save and delete failures are sanitized', () async {
    storage.scriptedWrites.add(Exception(_key));
    final saved = await repository.saveApiKey(_credential(), isTestnet: false);
    expect(
      saved,
      isA<Err<void, ExchangeFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeApiKeySaveFailure>(),
      ),
    );
    if (saved case Err(:final failure)) {
      expect(failure.logMessage, isNot(contains(_key)));
    }
    storage.scriptedWrites.add(Exception(_key));
    expect(
      await repository.deleteApiKey(isTestnet: false),
      isA<Err<void, ExchangeFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeApiKeyDeleteFailure>(),
      ),
    );
  });

  test('delete affects only the selected environment', () async {
    storage.entries['mainnet'] = jsonEncode(_fields);
    storage.entries['testnet'] = jsonEncode(_fields);
    expect(
      await repository.deleteApiKey(isTestnet: true),
      isA<Ok<void, ExchangeFailure>>(),
    );
    expect(storage.entries.keys, ['mainnet']);
  });
}
