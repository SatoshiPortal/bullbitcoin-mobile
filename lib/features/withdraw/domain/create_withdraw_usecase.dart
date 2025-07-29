import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/withdraw_error.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class CreateWithdrawalOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;

  CreateWithdrawalOrderUsecase({
    required ExchangeOrderRepository mainnetExchangeOrderRepository,
    required ExchangeOrderRepository testnetExchangeOrderRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetExchangeOrderRepository = mainnetExchangeOrderRepository,
       _testnetExchangeOrderRepository = testnetExchangeOrderRepository,
       _settingsRepository = settingsRepository;

  Future<WithdrawOrder> execute({
    required double fiatAmount,
    required String recipientId,
    required String paymentProcessor,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo =
          isTestnet
              ? _testnetExchangeOrderRepository
              : _mainnetExchangeOrderRepository;
      final order = await repo.placeWithdrawalOrder(
        fiatAmount: fiatAmount,
        recipientId: recipientId,
        paymentProcessor: paymentProcessor,
      );
      return order;
    } on WithdrawError {
      rethrow;
    } catch (e) {
      log.severe('Error in CreateWithdrawalOrderUsecase: $e');
      throw WithdrawError.unexpected(message: '$e');
    }
  }
}
