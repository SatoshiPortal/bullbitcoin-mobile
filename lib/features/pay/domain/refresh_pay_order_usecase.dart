import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/pay_error.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class RefreshPayOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;

  RefreshPayOrderUsecase({
    required this._mainnetExchangeOrderRepository,
    required this._testnetExchangeOrderRepository,
    required this._settingsRepository,
  });

  Future<FiatPaymentOrder> execute({
    required String orderId,
    required String? expectedDepositAddress,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet
          ? _testnetExchangeOrderRepository
          : _mainnetExchangeOrderRepository;
      final order = await repo.refreshPayOrder(orderId);
      validatePayOrderDepositAddress(
        order: order,
        expectedDepositAddress: expectedDepositAddress,
      );
      return order;
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      if (e is PayError) {
        rethrow;
      }
      throw PayError.unexpected(message: '$e');
    }
  }
}

void validatePayOrderDepositAddress({
  required FiatPaymentOrder order,
  required String? expectedDepositAddress,
}) {
  if (expectedDepositAddress == null ||
      expectedDepositAddress.isEmpty ||
      order.toAddress != expectedDepositAddress) {
    throw const PayError.depositAddressChanged();
  }
}
