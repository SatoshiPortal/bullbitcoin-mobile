import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
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
  @useResult
  Future<Result<FiatPaymentOrder, PayFailure>> execute({
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

      return Ok(order);
    } on ApiKeyException catch (e, st) {
      // Severe: a session that expired mid-flow is not something the user did
      // wrong, and it is the one failure here worth finding in Sentry.
      log.severe(
        message: 'Pay order rejected: not authenticated',
        error: e,
        trace: st,
      );
      return Err(PayUnauthenticatedFailure(e.message));
    } on BullBitcoinApiMinAmountException catch (e) {
      // The two amount bounds are expected user input errors, so they are
      // logged at info rather than severe. The bound is carried on the failure
      // for the day payBelowMinAmountError takes a placeholder; today's string
      // has none, so nothing reads it yet.
      log.info('Pay order below the minimum: ${e.message}');
      return Err(
        PayBelowMinAmountFailure(
          minAmount: e.minAmount,
          currency: e.currency,
          logMessage: e.message,
        ),
      );
    } on BullBitcoinApiMaxAmountException catch (e) {
      log.info('Pay order above the maximum: ${e.message}');
      return Err(
        PayAboveMaxAmountFailure(
          maxAmount: e.maxAmount,
          currency: e.currency,
          logMessage: e.message,
        ),
      );
    } catch (e, st) {
      log.severe(message: 'Failed to place the pay order', error: e, trace: st);
      return Err(PayUnexpectedFailure('$e'));
    }
  }
}
