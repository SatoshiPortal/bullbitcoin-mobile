import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order_stats.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_stats_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:primitives/primitives.dart';

/// Order statistics through the `bbx_api` package.
class BbxApiOrderStatsRepository implements ExchangeOrderStatsRepository {
  final bbx.Bbx _api;

  BbxApiOrderStatsRepository({required this._api});

  @override
  Future<OrderStatsResponse> getOrderStats() async {
    final result = await _api.orders.getOrderStats();
    return switch (result) {
      Ok(:final value) => _toEntity(value),
      Err(failure: bbx.BbxMissingCredentialFailure()) =>
        throw ApiKeyNotFoundException(),
      Err(failure: bbx.BbxCredentialUnavailableFailure()) =>
        throw const ExchangeCredentialUnavailableException(),
      Err(:final failure) => throw Exception(
        'Failed to get order stats: ${_describe(failure)}',
      ),
    };
  }

  static OrderStatsResponse _toEntity(bbx.OrderStatsReport report) {
    List<AmountByCurrencyCode> amounts(List<bbx.CurrencyAmount> wire) => [
      for (final a in wire)
        AmountByCurrencyCode(currency: a.currency, value: a.value),
    ];
    final orders = report.orderStats;
    final billers = report.billerStats;
    return OrderStatsResponse(
      orderStats: OrderStats(
        bitcoinBuyVolume: amounts(orders.bitcoinBuyVolume),
        bitcoinBuyTradeCount: amounts(orders.bitcoinBuyTradeCount),
        averageBitcoinBuyPrice: amounts(orders.averageBitcoinBuyPrice),
        bitcoinSellVolume: amounts(orders.bitcoinSellVolume),
        bitcoinSellTradeCount: amounts(orders.bitcoinSellTradeCount),
        averageBitcoinSellPrice: amounts(orders.averageBitcoinSellPrice),
        totalBitcoinTradingVolume: amounts(orders.totalBitcoinTradingVolume),
        buySellRatio: orders.buySellRatio,
      ),
      billerStats: BillerStats(
        currency: billers.currency,
        stats: [
          for (final s in billers.stats)
            BillerStat(
              billerName: s.billerName,
              billerCode: s.billerCode,
              totalAmount: s.totalAmount,
              tradeCount: s.tradeCount,
            ),
        ],
      ),
      asOf: report.asOf,
    );
  }

  static String _describe(bbx.BbxFailure failure) => switch (failure) {
    bbx.BbxRpcFailure(:final code, :final apiCode) =>
      'BbxRpcFailure(code: $code, apiCode: $apiCode)',
    _ => failure.runtimeType.toString(),
  };
}
