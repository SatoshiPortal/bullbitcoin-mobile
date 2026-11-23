import 'package:bull_exchange/src/payin/payin_wallets.dart';
import 'package:sync/sync.dart' show BitcoinSpendStatus, WalletKey;
import 'package:bull_exchange/src/sell/domain/map_sell_order_failure.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_exchange/src/sell/domain/sell_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class CreateSellOrderUsecase {
  final Exchange _exchange;
  final Preferences _settingsRepository;
  final PayjoinPolicyAccess _payjoinPolicy;
  final PayinWallets _wallets;

  CreateSellOrderUsecase({
    required this._exchange,
    required this._settingsRepository,
    required this._payjoinPolicy,
    required this._wallets,
  });

  /// [usePayjoin] is a request, not an instruction: it is resolved here against
  /// the global payjoin setting and the network, so a caller can pass the user's
  /// intent without also having to re-check the policy. The exchange applies its
  /// own pilot gate on top.
  @useResult
  Future<Result<Order, SellFailure>> execute({
    required OrderAmount orderAmount,
    required WalletKey? walletKey,
    required FiatCurrency currency,
    required OrderBitcoinNetwork network,
    bool usePayjoin = false,
    RecipientSelection? recipient,
  }) async {
    if (recipient != null && recipient.type.currencyCode != currency.code) {
      return const Err(SellUnexpectedFailure('Invalid sell recipient'));
    }
    if (recipient?.requiresVirtualPayeeActivation ?? false) {
      return const Err(SellConfidentialSepaNotActivatedFailure());
    }
    try {
      if (walletKey != null) {
        final status = await _wallets.eligibility(walletKey);
        if (status != BitcoinSpendStatus.ready) {
          return Err(
            SellSpendBlockedFailure(busy: status == BitcoinSpendStatus.busy),
          );
        }
      }
      final SettingsEntity settings;
      switch (await _settingsRepository.fetch()) {
        case Ok(:final value):
          settings = value;
        case Err():
          return const Err(SellUnexpectedFailure('Preferences read failed'));
      }
      if (!NetworkCapabilities.supports(
        BitcoinNetwork.fromName(settings.environment.name),
        NetworkCapability.exchange,
      )) {
        return const Err(SellUnsupportedNetworkFailure());
      }
      if (walletKey != null &&
          (walletKey.network.env != settings.environment.networkEnv ||
              network !=
                  (walletKey.network is BitcoinNetwork
                      ? OrderBitcoinNetwork.bitcoin
                      : OrderBitcoinNetwork.liquid))) {
        return const Err(SellSpendBlockedFailure(busy: false));
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
        'Sell Payjoin order request: requested=$usePayjoin, '
        'sellEnabled=$payjoinEnabled, '
        'network=${network.value}, sent=$resolvedUsePayjoin',
      );
      final Result<Order, ExchangeFailure> result;
      if (recipient == null) {
        result = await repo.placeSellOrder(
          orderAmount: orderAmount,
          currency: currency,
          network: network,
          usePayjoin: resolvedUsePayjoin,
        );
      } else {
        result = await repo.placePayOrder(
          orderAmount: orderAmount,
          recipientId: recipient.id,
          network: network,
          paymentProcessor: switch (recipient.type) {
            RecipientType.confidentialSepaEur =>
              SepaPaymentProcessor.confidential,
            RecipientType.sepaEur => SepaPaymentProcessor.regular,
            _ => null,
          },
          usePayjoin: resolvedUsePayjoin,
        );
      }
      final Order order;
      switch (result) {
        case Ok(:final value):
          order = value;
        case Err(:final failure):
          return Err(mapSellOrderFailure(failure));
      }
      log.fine(
        'Sell Payjoin order response: requested=$resolvedUsePayjoin, '
        'bip21Present=${order.payjoinBip21 != null}',
      );
      return Ok(order);
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to place the sell order',
        error: e.runtimeType,
        trace: st,
      );
      return Err(SellUnexpectedFailure(e.runtimeType.toString()));
    }
  }
}
