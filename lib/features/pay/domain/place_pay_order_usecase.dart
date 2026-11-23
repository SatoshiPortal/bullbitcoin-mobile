import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/pay/domain/map_pay_order_failure.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class PlacePayOrderUsecase {
  final Exchange _exchange;
  final Preferences _settingsRepository;
  final PayjoinPolicyAccess _payjoinPolicy;
  final WalletFacade _wallet;

  PlacePayOrderUsecase({
    required this._exchange,
    required this._settingsRepository,
    required this._payjoinPolicy,
    required this._wallet,
  });

  /// [usePayjoin] behaves as in CreateSellOrderUsecase: a payment is a sell to a
  /// recipient, and the request is resolved here against the same policy.
  @useResult
  Future<Result<FiatPaymentOrder, PayFailure>> execute({
    required OrderAmount orderAmount,
    required String? walletId,
    required String recipientId,
    required OrderBitcoinNetwork network,
    String? paymentDescription,
    bool usePayjoin = false,
  }) async {
    try {
      if (walletId != null && network == OrderBitcoinNetwork.bitcoin) {
        final status = await _wallet.spendStatus(walletId);
        if (status != BitcoinSpendStatus.ready) {
          return Err(
            PaySpendBlockedFailure(busy: status == BitcoinSpendStatus.busy),
          );
        }
      }
      final SettingsEntity settings;
      switch (await _settingsRepository.fetch()) {
        case Ok(:final value):
          settings = value;
        case Err():
          return const Err(PayUnexpectedFailure('Preferences read failed'));
      }
      if (!NetworkCapabilities.supports(
        BitcoinNetwork.fromName(settings.environment.name),
        NetworkCapability.exchange,
      )) {
        return const Err(PayUnsupportedNetworkFailure());
      }
      final payjoinEnabled = switch (await _payjoinPolicy.load()) {
        Ok(:final value) => value.sellEnabled,
        Err() => false,
      };
      final isTestnet = settings.environment.requireHistoricalTestnet();
      final repo = _exchange.orders(
        isTestnet ? ExchangeEnvironment.testnet : ExchangeEnvironment.mainnet,
      );

      final resolvedUsePayjoin =
          usePayjoin &&
          payjoinEnabled &&
          network == OrderBitcoinNetwork.bitcoin;
      log.fine(
        'Pay Payjoin order request: requested=$usePayjoin, '
        'sellEnabled=$payjoinEnabled, '
        'network=${network.value}, sent=$resolvedUsePayjoin',
      );
      final FiatPaymentOrder order;
      switch (await repo.placePayOrder(
        orderAmount: orderAmount,
        recipientId: recipientId,
        network: network,
        paymentDescription: paymentDescription,
        usePayjoin: resolvedUsePayjoin,
      )) {
        case Ok(:final value):
          order = value;
        case Err(:final failure):
          return Err(mapPayOrderFailure(failure));
      }
      log.fine(
        'Pay Payjoin order response: requested=$resolvedUsePayjoin, '
        'bip21Present=${order.bip21URI != null}',
      );

      return Ok(order);
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to place the pay order',
        error: e.runtimeType,
        trace: st,
      );
      return Err(PayUnexpectedFailure(e.runtimeType.toString()));
    }
  }
}
