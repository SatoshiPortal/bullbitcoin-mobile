import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';

class ConfirmBuyOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;
  final LabelsFacade _labelsFacade;

  ConfirmBuyOrderUsecase({
    required this._mainnetExchangeOrderRepository,
    required this._testnetExchangeOrderRepository,
    required this._settingsRepository,
    required this._labelsFacade,
  });

  @useResult
  Future<Result<BuyOrder, BuyFailure>> execute({
    required String orderId,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet
          ? _testnetExchangeOrderRepository
          : _mainnetExchangeOrderRepository;
      final order = await repo.confirmBuyOrder(orderId);

      if (order.toAddress != null) {
        await _labelsFacade.store(
          NewLabel.addr(
            address: order.toAddress!,
            label: LabelSystem.exchangeBuy.label,
          ),
        );
      }

      return Ok(order);
    } on ApiKeyException catch (e, st) {
      log.severe(
        message: 'Cannot confirm the buy order: not authenticated',
        error: e,
        trace: st,
      );
      return Err(BuyUnauthenticatedFailure(e.message));
    } catch (e, st) {
      log.severe(
        message: 'Failed to confirm the buy order',
        error: e,
        trace: st,
      );
      return Err(BuyUnexpectedFailure('$e'));
    }
  }
}
