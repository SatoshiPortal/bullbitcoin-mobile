import 'package:bull_exchange/src/buy/domain/map_buy_order_failure.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_exchange/src/buy/domain/buy_failure.dart';
import 'package:bull_exchange/src/buy/domain/buy_payjoin_window.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show validateAddress;

class CreateBuyOrderUsecase {
  final Exchange _exchange;
  final Preferences _settingsRepository;
  final PayjoinReceiver _payjoinReceiver;
  final PayjoinPolicyAccess _payjoinPolicy;

  CreateBuyOrderUsecase({
    required this._exchange,
    required this._settingsRepository,
    required this._payjoinReceiver,
    required this._payjoinPolicy,
  });

  /// Places a buy order, paying out through payjoin when it is possible.
  ///
  /// [payjoinWalletId] and [payjoinAmountSat] are what makes a payjoin payout
  /// possible: a session is opened on that wallet and the exchange is handed the
  /// resulting BIP21 URI instead of a bare address. Leave either null — an
  /// external address, a watch-only wallet, Liquid — and the order is placed the
  /// way it always was.
  ///
  /// [payjoinAmountSat] only has to be close: the exchange replaces the amount
  /// inside the URI with the one it actually pays. It is required because the
  /// exchange rejects a payjoin URI without an amount.
  @useResult
  Future<Result<BuyOrder, BuyFailure>> execute({
    required String toAddress,
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required BtcNetwork network,
    required bool isOwner,
    Environment? expectedEnvironment,
    String? payjoinWalletId,
    int? payjoinAmountSat,
  }) async {
    try {
      final SettingsEntity settings;
      switch (await _settingsRepository.fetch()) {
        case Ok(:final value):
          settings = value;
        case Err():
          return const Err(BuyUnexpectedFailure('Preferences read failed'));
      }
      if (expectedEnvironment != null &&
          settings.environment != expectedEnvironment) {
        return const Err(BuyUnexpectedFailure('Buy environment changed'));
      }
      final environment = settings.environment.networkEnv;
      final exchangeNetwork = switch (environment) {
        NetworkEnv.mainnet => BitcoinNetwork.mainnet,
        NetworkEnv.testnet => BitcoinNetwork.testnet,
        NetworkEnv.regtest => BitcoinNetwork.regtest,
        NetworkEnv.signet => BitcoinNetwork.signet,
      };
      if (!NetworkCapabilities.supports(
        exchangeNetwork,
        NetworkCapability.exchange,
      )) {
        log.warning('Capability refused feature=buy reason=unsupported');
        return const Err(BuyUnsupportedNetworkFailure());
      }
      final isTestnet = environment == NetworkEnv.testnet;
      final repo = _exchange.orders(
        isTestnet ? ExchangeEnvironment.testnet : ExchangeEnvironment.mainnet,
      );
      final Network payoutNetwork = network == BtcNetwork.liquid
          ? LiquidNetwork.fromName(settings.environment.name)
          : exchangeNetwork;
      if (expectedEnvironment != null &&
          await validateAddress(toAddress, payoutNetwork) is Err) {
        return const Err(BuyUnexpectedFailure('Buy payout network mismatch'));
      }

      final policyResult = await _payjoinPolicy.load();
      final payjoinEnabled = switch (policyResult) {
        Ok(:final value) => value.buyEnabled,
        Err() => false,
      };
      final wantsPayjoin =
          network == BtcNetwork.bitcoin &&
          payjoinEnabled &&
          payjoinWalletId != null &&
          payjoinAmountSat != null;

      String? payjoinId;
      String? payjoinBip21;
      if (wantsPayjoin) {
        try {
          final result = await _payjoinReceiver.start(
            StartPayjoinReceiver(
              walletId: payjoinWalletId,
              network: isTestnet
                  ? BitcoinNetwork.testnet
                  : BitcoinNetwork.mainnet,
              address: toAddress,
              amount: Sats.fromInt(payjoinAmountSat),
              isTrade: true,
              // The window the exchange negotiates a payout payjoin in. The
              // user's configured session lifetime may shorten it.
              // The previous 24h protocol maximum only resumed and re-watched
              // a dead session on every app start for a day.
              //
              // Expiring costs nothing either. The BIP21 still carries a plain
              // address, so an exchange payout that arrives late is an ordinary
              // payment; only the payjoin is lost. And an idle receiver freezes
              // no coins — `getUtxosFrozenByOngoingPayjoins` skips a session
              // whose proposal PSBT is null, which is exactly a session no
              // sender ever contacted.
              expiresAt: DateTime.now().add(BuyPayjoinWindow.duration),
            ),
          );
          switch (result) {
            case Ok(:final value):
              payjoinId = value.id;
              payjoinBip21 = value.pjUri;
              log.fine('Buy Payjoin receiver attached: ref=${value.logRef}');
            case Err(:final failure):
              log.warning(
                'Buy Payjoin unavailable; the order pays a plain address',
                error: '${failure.runtimeType}',
              );
          }
        } catch (e) {
          // Payjoin is an improvement on a purchase, never a precondition for
          // one. Anything that stops a session from opening — no spendable
          // utxo, a relay outage, a wallet that cannot sign — falls back to the
          // plain address the flow has always used. Only the cause's type is
          // logged: foreign exception text can quote the payment request.
          log.warning(
            'Buy Payjoin unavailable; the order pays a plain address',
            error: '${e.runtimeType}',
          );
        }
      }

      Future<void> cancelOrphanReceiver() async {
        // The session would otherwise sit and poll the directory for a day for
        // an order that never existed.
        if (payjoinId case final id?) {
          final result = await _payjoinReceiver.cancel(id);
          if (result case Err()) {
            log.warning('Failed to drop an orphan Payjoin session');
          }
        }
      }

      try {
        final result = await repo.placeBuyOrder(
          toAddress: toAddress,
          orderAmount: orderAmount,
          currency: currency,
          network: network,
          isOwner: isOwner,
          payjoinBip21: payjoinBip21,
        );
        final BuyOrder order;
        switch (result) {
          case Ok(:final value):
            order = value;
          case Err(:final failure):
            // A stale completion may have created an order on the old
            // session. Do not cancel its receiver or repeat the write.
            if (failure is! ExchangeOperationStaleFailure) {
              await cancelOrphanReceiver();
            }
            return Err(mapBuyOrderFailure(failure));
        }
        // Some create/confirm responses do not echo the submitted BIP21 URI.
        // Preserve the local URI so the confirmation and success screens know
        // that this order has an active receiver.
        final orderWithPayjoin = payjoinBip21 != null && order.bip21URI == null
            ? order.copyWith(bip21URI: payjoinBip21)
            : order;
        return Ok(orderWithPayjoin);
      } on Exception {
        await cancelOrphanReceiver();
        rethrow;
      }
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to place the buy order',
        error: e.runtimeType,
        trace: st,
      );
      return Err(BuyUnexpectedFailure(e.runtimeType.toString()));
    }
  }
}
