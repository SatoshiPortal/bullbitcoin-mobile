import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/order_stats_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order_stats.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_stats_repository.dart';

class ExchangeOrderStatsRepositoryImpl implements ExchangeOrderStatsRepository {
  final BullbitcoinApiDatasource _bullbitcoinApiDatasource;
  final BullbitcoinApiKeyDatasource _bullbitcoinApiKeyDatasource;
  final bool _isTestnet;

  ExchangeOrderStatsRepositoryImpl({
    required BullbitcoinApiDatasource bullbitcoinApiDatasource,
    required BullbitcoinApiKeyDatasource bullbitcoinApiKeyDatasource,
    required bool isTestnet,
  }) : _bullbitcoinApiDatasource = bullbitcoinApiDatasource,
       _bullbitcoinApiKeyDatasource = bullbitcoinApiKeyDatasource,
       _isTestnet = isTestnet;

  Future<String> _getApiKey() async {
    final apiKey = await _bullbitcoinApiKeyDatasource.get(isTestnet: _isTestnet);
    if (apiKey == null || !apiKey.isActive) {
      throw ApiKeyException(
        'API key not found. Please login to your Bull Bitcoin account.',
      );
    }
    return apiKey.key;
  }

  @override
  Future<OrderStatsResponse> getOrderStats() async {
    try {
      final apiKey = await _getApiKey();

      final json = await _bullbitcoinApiDatasource.getOrderStats(apiKey: apiKey);
      final model = OrderStatsResponseModel.fromJson(json);
      return model.toEntity();
    } catch (e) {
      if (e is ApiKeyException) rethrow;
      throw Exception('Failed to get order stats: $e');
    }
  }
}

