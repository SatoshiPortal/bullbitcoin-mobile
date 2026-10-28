import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bbx_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/mappers/bbx_api_mapper.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order_stats.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_stats_repository.dart';

/// [ExchangeOrderStatsRepository] on the shared `bbx_api` client.
class BbxApiExchangeOrderStatsRepository
    implements ExchangeOrderStatsRepository {
  final BbxApiDatasource _api;
  final BullbitcoinApiKeyDatasource _apiKeyDatasource;
  final bool _isTestnet;

  BbxApiExchangeOrderStatsRepository({
    required this._api,
    required this._apiKeyDatasource,
    required this._isTestnet,
  });

  @override
  Future<OrderStatsResponse> getOrderStats() async {
    try {
      final apiKey = await _apiKeyDatasource.get(isTestnet: _isTestnet);
      if (apiKey == null || !apiKey.isActive) {
        throw ApiKeyException(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
      }
      return BbxApiMapper.orderStats(
        (await _api.orders.getOrderStats()).unwrap(),
      );
    } catch (e) {
      if (e is ApiKeyException) rethrow;
      throw Exception('Failed to get order stats: $e');
    }
  }
}
