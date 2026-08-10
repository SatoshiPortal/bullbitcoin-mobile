import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/sell_error.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class RefreshSellOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;

  RefreshSellOrderUsecase({
    required this._mainnetExchangeOrderRepository,
    required this._testnetExchangeOrderRepository,
    required this._settingsRepository,
  });

  Future<SellOrder> execute({
    required String orderId,
    required String? expectedDepositAddress,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet
          ? _testnetExchangeOrderRepository
          : _mainnetExchangeOrderRepository;
      final order = await repo.refreshSellOrder(orderId);
      validateSellOrderDepositAddress(
        order: order,
        expectedDepositAddress: expectedDepositAddress,
      );
      return order;
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      if (e is SellError) {
        rethrow;
      }
      throw SellError.unexpected(message: '$e');
    }
  }
}

void validateSellOrderDepositAddress({
  required SellOrder order,
  required String? expectedDepositAddress,
}) {
  if (expectedDepositAddress == null ||
      expectedDepositAddress.isEmpty ||
      order.toAddress != expectedDepositAddress) {
    throw const SellError.depositAddressChanged();
  }
}
