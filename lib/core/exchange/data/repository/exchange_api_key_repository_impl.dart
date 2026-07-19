import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/api_key_model.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';

class ExchangeApiKeyRepositoryImpl implements ExchangeApiKeyRepository {
  static const _credentialImportError =
      'Unable to import Bull Bitcoin credentials';
  static const _credentialDeletionError =
      'Unable to delete Bull Bitcoin credentials';

  final BullbitcoinApiKeyDatasource _bullbitcoinApiKeyDatasource;

  ExchangeApiKeyRepositoryImpl({required this._bullbitcoinApiKeyDatasource});

  @override
  Future<void> saveApiKey(
    Map<String, dynamic> apiKeyResponseData, {
    required bool isTestnet,
  }) async {
    final broadApiKeyData = apiKeyResponseData['apiKey'];
    final scopedApiKey = apiKeyResponseData['sellToFiatBalanceApiKey'];
    if (broadApiKeyData is! Map ||
        scopedApiKey is! String ||
        scopedApiKey.trim().isEmpty) {
      throw Exception(_credentialImportError);
    }

    late final ExchangeApiKeyModel apiKeyModel;
    try {
      apiKeyModel = ExchangeApiKeyModel.fromJson(
        Map<String, dynamic>.from(broadApiKeyData),
      );
    } catch (_) {
      throw Exception(_credentialImportError);
    }

    try {
      await _bullbitcoinApiKeyDatasource.storeSellToFiatBalanceApiKey(
        scopedApiKey,
        isTestnet: isTestnet,
      );
      await _bullbitcoinApiKeyDatasource.store(
        apiKeyModel,
        isTestnet: isTestnet,
      );
    } catch (_) {
      throw Exception(_credentialImportError);
    }
  }

  @override
  Future<void> deleteApiKey({required bool isTestnet}) async {
    var failed = false;
    try {
      await _bullbitcoinApiKeyDatasource.delete(isTestnet: isTestnet);
    } catch (_) {
      failed = true;
    }

    try {
      await _bullbitcoinApiKeyDatasource.deleteSellToFiatBalanceApiKey(
        isTestnet: isTestnet,
      );
    } catch (_) {
      failed = true;
    }

    if (failed) {
      throw Exception(_credentialDeletionError);
    }
  }
}
