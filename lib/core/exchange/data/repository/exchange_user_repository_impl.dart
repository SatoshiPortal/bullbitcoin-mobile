import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/mappers/user_summary_mapper.dart';
import 'package:bb_mobile/core/exchange/data/models/user_preference_payload_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class ExchangeUserRepositoryImpl implements ExchangeUserRepository {
  final BullbitcoinApiDatasource _bullbitcoinApiDatasource;
  final BullbitcoinApiKeyDatasource _bullbitcoinApiKeyDatasource;
  final bool _isTestnet;

  ExchangeUserRepositoryImpl({
    required BullbitcoinApiDatasource bullbitcoinApiDatasource,
    required BullbitcoinApiKeyDatasource bullbitcoinApiKeyDatasource,
    required bool isTestnet,
  }) : _bullbitcoinApiDatasource = bullbitcoinApiDatasource,
       _bullbitcoinApiKeyDatasource = bullbitcoinApiKeyDatasource,
       _isTestnet = isTestnet;

  @override
  Future<UserSummary?> getUserSummary() async {
    try {
      final apiKey = await _bullbitcoinApiKeyDatasource.get(
        isTestnet: _isTestnet,
      );
      if (apiKey == null) {
        log.severe('No API key found');
        throw ApiKeyException(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
      }
      try {
        final userSummaryModel = await _bullbitcoinApiDatasource.getUserSummary(
          apiKey.key,
        );
        if (userSummaryModel == null) {
          return null;
        }
        final userSummary = UserSummaryMapper.fromModelToEntity(
          userSummaryModel,
        );

        return userSummary;
      } catch (e) {
        throw Exception('Failed to fetch user summary: $e');
      }
    } catch (e) {
      if (e is ApiKeyException) {
        rethrow;
      } else {
        throw Exception('Failed to fetch user summary: $e');
      }
    }
  }

  @override
  Future<void> saveUserPreference({
    String? language,
    String? currency,
    String? dcaEnabled,
    String? autoBuyEnabled,
  }) async {
    try {
      final apiKey = await _bullbitcoinApiKeyDatasource.get(
        isTestnet: _isTestnet,
      );
      if (apiKey == null) {
        log.severe('No API key found');
        throw ApiKeyException(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
      }

      final params = UserPreferencePayloadModel(
        language: language,
        currencyCode: currency,
        dcaEnabled: dcaEnabled,
        autoBuyEnabled: autoBuyEnabled,
      );

      await _bullbitcoinApiDatasource.saveUserPreference(
        apiKey: apiKey.key,
        params: params,
      );
    } catch (e) {
      if (e is ApiKeyException) {
        rethrow;
      } else {
        throw Exception('Failed to save user preferences: $e');
      }
    }
  }
}
