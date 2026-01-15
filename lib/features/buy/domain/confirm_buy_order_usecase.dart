import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';

class ConfirmBuyOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;
  final LabelsFacade _labelsFacade;

  ConfirmBuyOrderUsecase({
    required ExchangeOrderRepository mainnetExchangeOrderRepository,
    required ExchangeOrderRepository testnetExchangeOrderRepository,
    required SettingsRepository settingsRepository,
    required LabelsFacade labelsFacade,
  }) : _mainnetExchangeOrderRepository = mainnetExchangeOrderRepository,
       _testnetExchangeOrderRepository = testnetExchangeOrderRepository,
       _settingsRepository = settingsRepository,
       _labelsFacade = labelsFacade;

  Future<BuyOrder> execute({required String orderId}) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet
          ? _testnetExchangeOrderRepository
          : _mainnetExchangeOrderRepository;
      final order = await repo.confirmBuyOrder(orderId);

      if (order.toAddress != null) {
        await _labelsFacade.store([
          StoreLabelEnvelope.addr(
            address: order.toAddress!,
            label: LabelSystem.exchangeBuy.label,
            origin: null,
          ),
        ]);
      }

      return order;
    } catch (e) {
      log.severe('Error in ConfirmBuyOrderUsecase: $e');
      throw ConfirmBuyOrderException('$e');
    }
  }
}

class ConfirmBuyOrderException extends BullException {
  ConfirmBuyOrderException(super.message);
}
