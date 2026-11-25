import 'dart:convert';

import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:synchronized/synchronized.dart';

import '../domain/entities/exchange_api_key.dart';
import '../domain/exchange_failure.dart';
import '../setup/exchange_credentials.dart';
import 'exchange_api_key_mapper.dart';
import 'storage/exchange_credential_storage.dart';

/// Owns credential persistence in the module database and maps storage
/// exceptions without logging their payload. A read failure is never a
/// signed-out state.
class StoredExchangeCredentials implements ExchangeCredentials {
  final ExchangeCredentialStorage _storage;
  final _mainnetMutationLock = Lock();
  final _testnetMutationLock = Lock();
  final _readFailureTypes = <bool, Type>{};

  StoredExchangeCredentials({required this._storage});

  Lock _mutationLock(bool isTestnet) =>
      isTestnet ? _testnetMutationLock : _mainnetMutationLock;

  @override
  Future<Result<String?, ExchangeFailure>> readActiveApiKey({
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

  Future<Result<String?, ExchangeFailure>> _readActiveApiKey({
    required bool isTestnet,
  }) async {
    final String? stored;
    try {
      stored = await _storage.readApiKeyRecord(isTestnet: isTestnet);
    } on Exception {
      return const Err(ExchangeCredentialReadFailure());
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
  Future<Result<void, ExchangeFailure>> saveApiKey(
    ExchangeApiKey apiKey, {
    required bool isTestnet,
  }) => _mutationLock(isTestnet).synchronized(() async {
    try {
      final apiKeyModel = ExchangeApiKeyMapper.toModel(apiKey);

      await _storage.writeApiKeyRecord(
        jsonEncode(apiKeyModel.toJson()),
        isTestnet: isTestnet,
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
  Future<Result<void, ExchangeFailure>> deleteApiKey({
    required bool isTestnet,
  }) => _mutationLock(isTestnet).synchronized(() async {
    try {
      await _storage.writeApiKeyRecord(null, isTestnet: isTestnet);
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
