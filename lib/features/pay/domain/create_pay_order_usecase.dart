import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/pay_error.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

class PlacePayOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;
  final PayjoinPolicyAccess _payjoinPolicy;

  PlacePayOrderUsecase({
    required this._mainnetExchangeOrderRepository,
    required this._testnetExchangeOrderRepository,
    required this._settingsRepository,
    required this._payjoinPolicy,
  });

  /// [usePayjoin] behaves as in CreateSellOrderUsecase: a payment is a sell to a
  /// recipient, and the request is resolved here against the same policy.
  Future<FiatPaymentOrder> execute({
    required OrderAmount orderAmount,
    required String recipientId,
    required OrderBitcoinNetwork network,
    String? paymentDescription,
    bool usePayjoin = false,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final payjoinEnabled = switch (await _payjoinPolicy.load()) {
        Ok(:final value) => value.enabled,
        Err() => false,
      };
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet
          ? _testnetExchangeOrderRepository
          : _mainnetExchangeOrderRepository;

      final order = await repo.placePayOrder(
        orderAmount: orderAmount,
        recipientId: recipientId,
        network: network,
        paymentDescription: paymentDescription,
        usePayjoin:
            usePayjoin &&
            payjoinEnabled &&
            network == OrderBitcoinNetwork.bitcoin,
      );

      return order;
    } on PayError {
      rethrow;
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      throw PayError.unexpected(message: '$e');
    }
  }
}
