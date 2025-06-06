import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/mappers/user_summary_mapper.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:flutter/cupertino.dart';

class ExchangeUserRepositoryImpl implements ExchangeUserRepository {
  final BullbitcoinApiDatasource _bullbitcoinApiDatasource;
  final BullbitcoinApiKeyDatasource _bullbitcoinApiKeyDatasource;

  ExchangeUserRepositoryImpl({
    required BullbitcoinApiDatasource bullbitcoinApiDatasource,
    required BullbitcoinApiKeyDatasource bullbitcoinApiKeyDatasource,
  }) : _bullbitcoinApiDatasource = bullbitcoinApiDatasource,
       _bullbitcoinApiKeyDatasource = bullbitcoinApiKeyDatasource;

  @override
  Future<UserSummary?> getUserSummary() async {
    try {
      final apiKey = await _bullbitcoinApiKeyDatasource.get();
      if (apiKey == null) {
        debugPrint('No API key found');
        throw ApiKeyException(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
      }
      final userSummaryModel = await _bullbitcoinApiDatasource.getUserSummary(
        apiKey.key,
      );
      if (userSummaryModel == null) {
        debugPrint('User summary not found for API key: ${apiKey.key}');
        return null;
      }
      final userSummary = UserSummaryMapper.fromModelToEntity(userSummaryModel);

      return userSummary;
    } catch (e) {
      throw Exception('Failed to fetch user summary: $e');
    }
  }
}
