import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/new_recipient_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/cad_biller.dart';
import 'package:bb_mobile/core/exchange/domain/entity/new_recipient.dart';
import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_recipient_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class ExchangeRecipientRepositoryImpl implements ExchangeRecipientRepository {
  final BullbitcoinApiDatasource _bullbitcoinApiDatasource;
  final BullbitcoinApiKeyDatasource _bullbitcoinApiKeyDatasource;
  final bool _isTestnet;

  ExchangeRecipientRepositoryImpl({
    required BullbitcoinApiDatasource bullbitcoinApiDatasource,
    required BullbitcoinApiKeyDatasource bullbitcoinApiKeyDatasource,
    required bool isTestnet,
  }) : _bullbitcoinApiDatasource = bullbitcoinApiDatasource,
       _bullbitcoinApiKeyDatasource = bullbitcoinApiKeyDatasource,
       _isTestnet = isTestnet;

  @override
  Future<List<Recipient>> listRecipients({bool fiatOnly = false}) async {
    try {
      final apiKeyModel = await _bullbitcoinApiKeyDatasource.get(
        isTestnet: _isTestnet,
      );

      if (apiKeyModel == null) {
        throw ApiKeyException(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
      }

      if (!apiKeyModel.isActive) {
        throw ApiKeyException(
          'API key is inactive. Please login again to your Bull Bitcoin account.',
        );
      }

      log.info('ListRecipients API Key: ${apiKeyModel.key}');
      final recipientModels =
          fiatOnly
              ? await _bullbitcoinApiDatasource.listRecipientsFiat(
                apiKey: apiKeyModel.key,
              )
              : await _bullbitcoinApiDatasource.listRecipients(
                apiKey: apiKeyModel.key,
              );

      return recipientModels.map((model) => model.toEntity()).toList();
    } catch (e) {
      log.severe('Error fetching recipients: $e');
      return [];
    }
  }

  @override
  Future<Recipient> createFiatRecipient(NewRecipient recipient) async {
    log.info('🚀 createFiatRecipient called in repository');
    log.info('📊 Recipient type: ${recipient.recipientTypeFiat}');
    log.info('🌐 Is testnet: $_isTestnet');

    try {
      log.info('🔑 Fetching API key...');
      final apiKeyModel = await _bullbitcoinApiKeyDatasource.get(
        isTestnet: _isTestnet,
      );

      if (apiKeyModel == null) {
        throw ApiKeyException(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
      }

      if (!apiKeyModel.isActive) {
        throw ApiKeyException(
          'API key is inactive. Please login again to your Bull Bitcoin account.',
        );
      }

      // Convert entity to model at datasource level
      final recipientModel = NewRecipientModel.fromEntity(recipient);
      log.info('📊 Recipient model: $recipientModel');
      final createdRecipient = await _bullbitcoinApiDatasource
          .createFiatRecipient(
            recipient: recipientModel,
            apiKey: apiKeyModel.key,
          );

      return createdRecipient.toEntity();
    } catch (e) {
      log.severe('Error creating fiat recipient: $e');
      rethrow;
    }
  }

  @override
  Future<List<CadBiller>> listCadBillers({required String searchTerm}) async {
    try {
      final apiKeyModel = await _bullbitcoinApiKeyDatasource.get(
        isTestnet: _isTestnet,
      );

      if (apiKeyModel == null) {
        throw ApiKeyException(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
      }

      if (!apiKeyModel.isActive) {
        throw ApiKeyException(
          'API key is inactive. Please login again to your Bull Bitcoin account.',
        );
      }

      final cadBillerModels = await _bullbitcoinApiDatasource.listCadBillers(
        apiKey: apiKeyModel.key,
        searchTerm: searchTerm,
      );

      return cadBillerModels.map((model) => model.toEntity()).toList();
    } catch (e) {
      log.severe('Error fetching CAD billers: $e');
      return [];
    }
  }
}
