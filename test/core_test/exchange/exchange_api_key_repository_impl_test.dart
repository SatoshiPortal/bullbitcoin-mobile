import 'dart:convert';

import 'package:bb_mobile/core/exchange/data/exchange_api_key_repository_impl.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

class _Storage extends Fake implements KeyValueStorageDatasource<String> {
  final values = <String, String>{};
  final reads = <String>[];
  Exception? readFailure;
  Exception? writeFailure;
  Exception? deleteFailure;

  @override
  Future<String?> getValue(String key) async {
    reads.add(key);
    final failure = readFailure;
    if (failure != null) throw failure;
    return values[key];
  }

  @override
  Future<void> saveValue({required String key, required String value}) async {
    final failure = writeFailure;
    if (failure != null) throw failure;
    values[key] = value;
  }

  @override
  Future<void> deleteValue(String key) async {
    final failure = deleteFailure;
    if (failure != null) throw failure;
    values.remove(key);
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

void main() {
  late _Storage storage;
  late ExchangeApiKeyRepositoryImpl repository;

  setUp(() {
    storage = _Storage();
    repository = ExchangeApiKeyRepositoryImpl(secureStorage: storage);
  });

  test('reads selected environment at point of use without caching', () async {
    storage.values['exchange_api_key'] = jsonEncode(_fields);
    storage.values['exchange_api_key_testnet'] = jsonEncode({
      ..._fields,
      'key': 'test-only',
    });
    expect(
      await repository.readActiveApiKey(isTestnet: false),
      isA<Ok<String?, ExchangeApiKeyFailure>>().having(
        (r) => r.value,
        'key',
        _key,
      ),
    );
    expect(
      await repository.readActiveApiKey(isTestnet: true),
      isA<Ok<String?, ExchangeApiKeyFailure>>().having(
        (r) => r.value,
        'key',
        'test-only',
      ),
    );
    storage.values['exchange_api_key'] = jsonEncode({
      ..._fields,
      'key': 'replacement',
    });
    expect(
      await repository.readActiveApiKey(isTestnet: false),
      isA<Ok<String?, ExchangeApiKeyFailure>>().having(
        (r) => r.value,
        'key',
        'replacement',
      ),
    );
    storage.values.remove('exchange_api_key');
    expect(
      await repository.readActiveApiKey(isTestnet: false),
      isA<Ok<String?, ExchangeApiKeyFailure>>().having(
        (r) => r.value,
        'key',
        isNull,
      ),
    );
    expect(storage.reads, [
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
        storage.values.clear();
      } else {
        storage.values['exchange_api_key'] = stored;
      }
      expect(
        await repository.readActiveApiKey(isTestnet: false),
        isA<Ok<String?, ExchangeApiKeyFailure>>().having(
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
      storage.values['exchange_api_key'] = jsonEncode({
        'key': _key,
        'isActive': true,
        'createdAt': 'invalid',
        'expiresAt': 0,
      });
      expect(
        await repository.readActiveApiKey(isTestnet: false),
        isA<Ok<String?, ExchangeApiKeyFailure>>().having(
          (r) => r.value,
          'key',
          _key,
        ),
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
        storage.values['exchange_api_key'] = record;
        final result = await repository.readActiveApiKey(isTestnet: false);
        expect(
          result,
          isA<Err<String?, ExchangeApiKeyFailure>>().having(
            (r) => r.failure,
            'failure',
            isA<ExchangeApiKeyInvalidFailure>(),
          ),
        );
        expect(storage.values['exchange_api_key'], record);
      }
    },
  );

  test(
    'storage refusal stays distinct from logout and never echoes its message',
    () async {
      storage.values['exchange_api_key'] = jsonEncode(_fields);
      storage.readFailure = Exception('keychain refused $_key');
      final result = await repository.readActiveApiKey(isTestnet: false);
      expect(
        result,
        isA<Err<String?, ExchangeApiKeyFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeApiKeyReadFailure>(),
        ),
      );
      if (result case Err(:final failure)) {
        expect(failure.logMessage, isNot(contains(_key)));
      }
      expect(storage.values, contains('exchange_api_key'));
    },
  );

  for (final entry in <String, Map<String, dynamic>>{
    'bare': _fields,
    'apiKey': {'apiKey': _fields},
    'result': {
      'result': {'apiKey': _fields},
    },
    'data': {
      'data': {'apiKey': _fields},
    },
  }.entries) {
    test('saves ${entry.key} auth envelope in the existing format', () async {
      expect(
        await repository.saveApiKey(entry.value, isTestnet: true),
        isA<Ok<void, ExchangeApiKeyFailure>>(),
      );
      expect(storage.values.keys, ['exchange_api_key_testnet']);
      expect(
        jsonDecode(storage.values['exchange_api_key_testnet'] ?? ''),
        containsPair('key', _key),
      );
    });
  }

  test('save and delete failures are sanitized', () async {
    storage.writeFailure = Exception(_key);
    final saved = await repository.saveApiKey(_fields, isTestnet: false);
    expect(
      saved,
      isA<Err<void, ExchangeApiKeyFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeApiKeySaveFailure>(),
      ),
    );
    if (saved case Err(:final failure)) {
      expect(failure.logMessage, isNot(contains(_key)));
    }
    storage.deleteFailure = Exception(_key);
    expect(
      await repository.deleteApiKey(isTestnet: false),
      isA<Err<void, ExchangeApiKeyFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeApiKeyDeleteFailure>(),
      ),
    );
  });

  test('delete affects only the selected environment', () async {
    storage.values['exchange_api_key'] = jsonEncode(_fields);
    storage.values['exchange_api_key_testnet'] = jsonEncode(_fields);
    expect(
      await repository.deleteApiKey(isTestnet: true),
      isA<Ok<void, ExchangeApiKeyFailure>>(),
    );
    expect(storage.values.keys, ['exchange_api_key']);
  });
}
