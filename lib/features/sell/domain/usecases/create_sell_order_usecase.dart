import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/sell_error.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:meta/meta.dart';

class CreateSellOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;

  CreateSellOrderUsecase({
    required this._mainnetExchangeOrderRepository,
    required this._testnetExchangeOrderRepository,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<SellOrder, SellFailure>> execute({
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required OrderBitcoinNetwork network,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet
          ? _testnetExchangeOrderRepository
          : _mainnetExchangeOrderRepository;
      final order = await repo.placeSellOrder(
        orderAmount: orderAmount,
        currency: currency,
        network: network,
      );
      return Ok(order);
    } on UnauthenticatedSellError {
      return const Err(SellUnauthenticatedFailure());
    } on BelowMinAmountSellError catch (e) {
      return Err(SellBelowMinAmountFailure(minAmountSat: e.minAmountSat));
    } on AboveMaxAmountSellError catch (e) {
      return Err(SellAboveMaxAmountFailure(maxAmountSat: e.maxAmountSat));
    } catch (e, st) {
      log.severe(message: 'create sell order failed', error: e, trace: st);
      return Err(SellUnexpectedFailure(e.toString()));
    }
  }
}
