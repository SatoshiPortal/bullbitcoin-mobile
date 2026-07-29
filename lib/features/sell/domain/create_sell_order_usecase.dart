import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/sell_error.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class CreateSellOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;

  CreateSellOrderUsecase({
    required this._mainnetExchangeOrderRepository,
    required this._testnetExchangeOrderRepository,
    required this._settingsRepository,
  });

  /// [usePayjoin] is a request, not an instruction: it is resolved here against
  /// the global payjoin setting and the network, so a caller can pass the user's
  /// intent without also having to re-check the policy. The exchange applies its
  /// own pilot gate on top.
  Future<SellOrder> execute({
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required OrderBitcoinNetwork network,
    bool usePayjoin = false,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet
          ? _testnetExchangeOrderRepository
          : _mainnetExchangeOrderRepository;
      final resolvedUsePayjoin =
          usePayjoin &&
          settings.isPayjoinEnabled &&
          network == OrderBitcoinNetwork.bitcoin;
      log.info(
        'Sell Payjoin order request: requested=$usePayjoin, '
        'globalEnabled=${settings.isPayjoinEnabled}, '
        'network=${network.value}, sent=$resolvedUsePayjoin',
      );
      final order = await repo.placeSellOrder(
        orderAmount: orderAmount,
        currency: currency,
        network: network,
        usePayjoin: resolvedUsePayjoin,
      );
      log.info(
        'Sell Payjoin order response: requested=$resolvedUsePayjoin, '
        'bip21Present=${order.bip21URI != null}',
      );
      return order;
    } on SellError {
      rethrow;
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      throw SellError.unexpected(message: '$e');
    }
  }
}
