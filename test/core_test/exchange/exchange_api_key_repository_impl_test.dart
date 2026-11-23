import 'package:exchange/exchange.dart';
import 'package:exchange/setup.dart';

import 'dart:convert';

import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';

class _Storage extends FakeSecureStoragePlatform {
  final readKeys = <String>[];
  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) {
    readKeys.add(key);
    return super.read(key: key, options: options);
  }
}

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
  late _Storage storage;
  late ExchangeCredentials repository;

  setUp(() {
    storage = _Storage()..install();
    repository = ExchangeCredentials.open(
      Secrets(scratchDirectory: () async => '/tmp').exchangeKeychain,
    );
  });

  test('reads selected environment at point of use without caching', () async {
    storage.entries['exchange_api_key'] = jsonEncode(_fields);
    storage.entries['exchange_api_key_testnet'] = jsonEncode({
      ..._fields,
      'key': 'test-only',
    });
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
    storage.entries['exchange_api_key'] = jsonEncode({
      ..._fields,
      'key': 'replacement',
    });
    expect(
      await repository.readActiveApiKey(isTestnet: false),
      isA<Ok<String?, ExchangeFailure>>().having(
        (r) => r.value,
        'key',
        'replacement',
      ),
    );
    storage.entries.remove('exchange_api_key');
    expect(
      await repository.readActiveApiKey(isTestnet: false),
      isA<Ok<String?, ExchangeFailure>>().having((r) => r.value, 'key', isNull),
    );
    expect(storage.readKeys, [
      'exchange_api_key',
      'exchange_api_key_testnet',
      'exchange_api_key',
      'exchange_api_key',
    ]);
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
        storage.entries['exchange_api_key'] = stored;
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
      storage.entries['exchange_api_key'] = jsonEncode({
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
        storage.entries['exchange_api_key'] = record;
        final result = await repository.readActiveApiKey(isTestnet: false);
        expect(
          result,
          isA<Err<String?, ExchangeFailure>>().having(
            (r) => r.failure,
            'failure',
            isA<ExchangeApiKeyInvalidFailure>(),
          ),
        );
        expect(storage.entries['exchange_api_key'], record);
      }
    },
  );

  test(
    'storage refusal stays distinct from logout and never echoes its message',
    () async {
      storage.entries['exchange_api_key'] = jsonEncode(_fields);
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
      expect(storage.entries, contains('exchange_api_key'));
    },
  );

  test('rejects credentials that cannot safely enter an HTTP header', () async {
    for (final key in [
      ' ',
      'synthetic\r\nheader',
      'synthetic\u0000',
      'synthetic\u{1f600}',
    ]) {
      storage.entries['exchange_api_key_testnet'] = jsonEncode({
        'key': key,
        'isActive': true,
      });
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
    expect(storage.entries.keys, ['exchange_api_key_testnet']);
    expect(jsonDecode(storage.entries['exchange_api_key_testnet'] ?? ''), {
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
    storage.entries['exchange_api_key'] = jsonEncode(_fields);
    storage.entries['exchange_api_key_testnet'] = jsonEncode(_fields);
    expect(
      await repository.deleteApiKey(isTestnet: true),
      isA<Ok<void, ExchangeFailure>>(),
    );
    expect(storage.entries.keys, ['exchange_api_key']);
  });
}
