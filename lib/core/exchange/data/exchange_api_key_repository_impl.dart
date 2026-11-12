import 'dart:convert';

import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/exchange/data/mappers/exchange_api_key_mapper.dart';
import 'package:bb_mobile/core/exchange/domain/entity/exchange_api_key.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:synchronized/synchronized.dart';

/// Owns credential persistence and maps storage exceptions without logging their payload.
class ExchangeApiKeyRepositoryImpl implements ExchangeApiKeyRepository {
  final KeyValueStorageDatasource<String> _secureStorage;
  final _mainnetMutationLock = Lock();
  final _testnetMutationLock = Lock();
  final _readFailureTypes = <bool, Type>{};

  ExchangeApiKeyRepositoryImpl({required this._secureStorage});

  static String _storageKey(bool isTestnet) =>
      isTestnet ? 'exchange_api_key_testnet' : 'exchange_api_key';

  Lock _mutationLock(bool isTestnet) =>
      isTestnet ? _testnetMutationLock : _mainnetMutationLock;

  @override
  Future<Result<String?, ExchangeApiKeyFailure>> readActiveApiKey({
    required bool isTestnet,
  }) async {
    final result = await _readActiveApiKey(isTestnet: isTestnet);
    final environment = isTestnet ? 'testnet' : 'mainnet';
    if (result case Err(:final failure)) {
      if (_readFailureTypes[isTestnet] != failure.runtimeType) {
        _readFailureTypes[isTestnet] = failure.runtimeType;
        log.warning(
          'Exchange credential read failed: env=$environment',
          error: failure.runtimeType,
        );
      }
    } else if (_readFailureTypes.remove(isTestnet) != null) {
      log.fine('Exchange credential read recovered: env=$environment');
    }
    return result;
  }

  Future<Result<String?, ExchangeApiKeyFailure>> _readActiveApiKey({
    required bool isTestnet,
  }) async {
    final String? stored;
    try {
      stored = await _secureStorage.getValue(_storageKey(isTestnet));
    } on Exception {
      return const Err(ExchangeApiKeyReadFailure());
    }
    if (stored == null || stored.isEmpty) return const Ok(null);
    try {
      // Authentication deliberately ignores account metadata and timestamps.
      return switch (jsonDecode(stored)) {
        {'key': final String key, 'isActive': final bool active}
            when ExchangeApiKey.isValidKey(key) =>
          Ok(active ? key : null),
        _ => const Err(ExchangeApiKeyInvalidFailure()),
      };
    } on FormatException {
      // FormatException embeds its source; report only the modeled failure type.
      return const Err(ExchangeApiKeyInvalidFailure());
    }
  }

  @override
  Future<Result<void, ExchangeApiKeyFailure>> saveApiKey(
    ExchangeApiKey apiKey, {
    required bool isTestnet,
  }) => _mutationLock(isTestnet).synchronized(() async {
    try {
      final apiKeyModel = ExchangeApiKeyMapper.toModel(apiKey);

      await _secureStorage.saveValue(
        key: _storageKey(isTestnet),
        value: jsonEncode(apiKeyModel.toJson()),
      );
      log.fine(
        'Exchange credential stored: env=${isTestnet ? 'testnet' : 'mainnet'}',
      );
      return const Ok(null);
    } on Exception catch (e, st) {
      log.warning(
        'Exchange credential write failed: env=${isTestnet ? 'testnet' : 'mainnet'}',
        error: e.runtimeType,
        trace: st,
      );
      return Err(ExchangeApiKeySaveFailure('store failed: ${e.runtimeType}'));
    }
  });

  @override
  Future<Result<void, ExchangeApiKeyFailure>> deleteApiKey({
    required bool isTestnet,
  }) => _mutationLock(isTestnet).synchronized(() async {
    try {
      await _secureStorage.deleteValue(_storageKey(isTestnet));
      log.fine(
        'Exchange credential removed: env=${isTestnet ? 'testnet' : 'mainnet'}',
      );
      return const Ok(null);
    } on Exception catch (e, st) {
      log.warning(
        'Exchange credential deletion failed: env=${isTestnet ? 'testnet' : 'mainnet'}',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        ExchangeApiKeyDeleteFailure('delete failed: ${e.runtimeType}'),
      );
    }
  });
}
