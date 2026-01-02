import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/mappers/virtual_iban_recipient_mapper.dart';
import 'package:bb_mobile/core/exchange/domain/entity/virtual_iban_recipient.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/virtual_iban_repository.dart';

/// Implementation of [VirtualIbanRepository] that uses the Bull Bitcoin API.
class VirtualIbanRepositoryImpl implements VirtualIbanRepository {
  final BullbitcoinApiDatasource _apiDatasource;
  final BullbitcoinApiKeyDatasource _apiKeyDatasource;
  final bool _isTestnet;

  VirtualIbanRepositoryImpl({
    required BullbitcoinApiDatasource apiDatasource,
    required BullbitcoinApiKeyDatasource apiKeyDatasource,
    required bool isTestnet,
  }) : _apiDatasource = apiDatasource,
       _apiKeyDatasource = apiKeyDatasource,
       _isTestnet = isTestnet;

  Future<String> _getApiKey() async {
    final apiKey = await _apiKeyDatasource.get(isTestnet: _isTestnet);

    if (apiKey == null) {
      throw ApiKeyException(
        'API key not found. Please login to your Bull Bitcoin account.',
      );
    }
    if (!apiKey.isActive) {
      throw ApiKeyException(
        'API key is inactive. Please login again to your Bull Bitcoin account.',
      );
    }

    return apiKey.key;
  }

  @override
  Future<VirtualIbanRecipient?> getVirtualIbanDetails() async {
    try {
      final apiKey = await _getApiKey();

      final model = await _apiDatasource.getVirtualIbanDetails(apiKey: apiKey);

      if (model == null) {
        return null;
      }

      return VirtualIbanRecipientMapper.fromModelToEntity(model);
    } on ApiKeyException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to get virtual IBAN details: $e');
    }
  }

  @override
  Future<VirtualIbanRecipient> createVirtualIban() async {
    try {
      final apiKey = await _getApiKey();

      final model = await _apiDatasource.createVirtualIban(apiKey: apiKey);

      return VirtualIbanRecipientMapper.fromModelToEntity(model);
    } on ApiKeyException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to create virtual IBAN: $e');
    }
  }

  @override
  Future<VirtualIbanRecipient> createFrPayeeRecipient({
    required String iban,
  }) async {
    try {
      final apiKey = await _getApiKey();

      final model = await _apiDatasource.createFrPayeeRecipient(
        apiKey: apiKey,
        iban: iban,
      );

      return VirtualIbanRecipientMapper.fromModelToEntity(model);
    } on ApiKeyException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to create FR_PAYEE recipient: $e');
    }
  }
}

