import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/order_stats_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order_stats.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_stats_repository.dart';

class ExchangeOrderStatsRepositoryImpl implements ExchangeOrderStatsRepository {
  final BullbitcoinApiDatasource _bullbitcoinApiDatasource;

  ExchangeOrderStatsRepositoryImpl({required this._bullbitcoinApiDatasource});

  @override
  Future<OrderStatsResponse> getOrderStats() async {
    try {
      final json = await _bullbitcoinApiDatasource.getOrderStats();
      final model = OrderStatsResponseModel.fromJson(json);
      return model.toEntity();
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      if (e is ApiKeyException) rethrow;
      throw Exception('Failed to get order stats: $e');
    }
  }
}
