import 'package:bull_exchange/src/payin/payin_wallets.dart';
import 'package:sync/sync.dart' show BitcoinSpendStatus, WalletKey;
import 'package:bull_exchange/src/pay/domain/map_pay_order_failure.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_exchange/src/pay/domain/pay_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class PlacePayOrderUsecase {
  final Exchange _exchange;
  final Preferences _settingsRepository;
  final PayjoinPolicyAccess _payjoinPolicy;
  final PayinWallets _wallets;

  PlacePayOrderUsecase({
    required this._exchange,
    required this._settingsRepository,
    required this._payjoinPolicy,
    required this._wallets,
  });

  /// [usePayjoin] behaves as in CreateSellOrderUsecase: a payment is a sell to a
  /// recipient, and the request is resolved here against the same policy.
  @useResult
  Future<Result<FiatPaymentOrder, PayFailure>> execute({
    required OrderAmount orderAmount,
    required WalletKey? walletKey,
    required String recipientId,
    required PayoutRail rail,
    required BtcNetwork network,
    String? paymentDescription,
    bool usePayjoin = false,
  }) async {
    try {
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
      if (walletKey != null &&
          (walletKey.network.env != settings.environment.networkEnv ||
              network !=
                  (walletKey.network is BitcoinNetwork
                      ? BtcNetwork.bitcoin
                      : BtcNetwork.liquid))) {
        return const Err(PayPayinNetworkMismatchFailure());
      }
      if (walletKey != null) {
        final status = await _wallets.eligibility(walletKey);
        if (status != BitcoinSpendStatus.ready) {
          return Err(
            PaySpendBlockedFailure(busy: status == BitcoinSpendStatus.busy),
          );
        }
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
          usePayjoin && payjoinEnabled && network == BtcNetwork.bitcoin;
      log.fine(
        'Pay Payjoin order request: requested=$usePayjoin, '
        'sellEnabled=$payjoinEnabled, '
        'network=${network.name}, sent=$resolvedUsePayjoin',
      );
      final FiatPaymentOrder order;
      switch (await repo.placePayOrder(
        orderAmount: orderAmount,
        recipientId: recipientId,
        network: network,
        paymentDescription: paymentDescription,
        paymentProcessor: rail.paymentProcessor,
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
