import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class RefreshBuyOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;

  RefreshBuyOrderUsecase({
    required this._mainnetExchangeOrderRepository,
    required this._testnetExchangeOrderRepository,
    required this._settingsRepository,
  });

  /// A fresh quote for an order awaiting confirmation; once [confirmed], the
  /// order as the exchange now sees it, which asks for no new quote.
  @useResult
  Future<Result<BuyOrder, BuyFailure>> execute({
    required String orderId,
    bool confirmed = false,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet
          ? _testnetExchangeOrderRepository
          : _mainnetExchangeOrderRepository;
      if (!confirmed) return Ok(await repo.refreshBuyOrder(orderId));
      final order = await repo.getOrder(orderId);
      if (order is! BuyOrder) {
        log.severe(
          error: 'Expected a buy order but read ${order.runtimeType}',
          trace: StackTrace.current,
        );
        return Err(BuyUnexpectedFailure('Not a buy order: $orderId'));
      }
      return Ok(order);
    } on ApiKeyException catch (e, st) {
      log.severe(
        message: 'Cannot refresh the buy order: not authenticated',
        error: e,
        trace: st,
      );
      return Err(BuyUnauthenticatedFailure(e.message));
    } catch (e, st) {
      log.severe(
        message: 'Failed to refresh the buy order',
        error: e,
        trace: st,
      );
      return Err(BuyUnexpectedFailure('$e'));
    }
  }
}
