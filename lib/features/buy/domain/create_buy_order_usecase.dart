import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bb_mobile/features/buy/domain/buy_payjoin_window.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class CreateBuyOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;
  final PayjoinReceiver _payjoinReceiver;
  final PayjoinPolicyAccess _payjoinPolicy;

  CreateBuyOrderUsecase({
    required this._mainnetExchangeOrderRepository,
    required this._testnetExchangeOrderRepository,
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
    required bool isLiquid,
    required bool isOwner,
    String? payjoinWalletId,
    int? payjoinAmountSat,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet
          ? _testnetExchangeOrderRepository
          : _mainnetExchangeOrderRepository;
      final network = isLiquid
          ? OrderBitcoinNetwork.liquid
          : OrderBitcoinNetwork.bitcoin;

      final policyResult = await _payjoinPolicy.load();
      final payjoinEnabled = switch (policyResult) {
        Ok(:final value) => value.buyEnabled,
        Err() => false,
      };
      final wantsPayjoin =
          !isLiquid &&
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

      try {
        final order = await repo.placeBuyOrder(
          toAddress: toAddress,
          orderAmount: orderAmount,
          currency: currency,
          network: network,
          isOwner: isOwner,
          payjoinBip21: payjoinBip21,
        );
        // Some create/confirm responses do not echo the submitted BIP21 URI.
        // Preserve the local URI so the confirmation and success screens know
        // that this order has an active receiver.
        final orderWithPayjoin = payjoinBip21 != null && order.bip21URI == null
            ? order.copyWith(bip21URI: payjoinBip21)
            : order;
        return Ok(orderWithPayjoin);
      } catch (_) {
        // The session would otherwise sit and poll the directory for a day for
        // an order that never existed.
        if (payjoinId != null) {
          final result = await _payjoinReceiver.cancel(payjoinId);
          if (result case Err()) {
            log.warning('Failed to drop an orphan Payjoin session');
          }
        }
        rethrow;
      }
    } on ApiKeyException catch (e, st) {
      // Severe: a session that expired mid-flow is not something the user did
      // wrong, and it is the one failure here worth finding in Sentry.
      log.severe(
        message: 'Buy order rejected: not authenticated',
        error: e,
        trace: st,
      );
      return Err(BuyUnauthenticatedFailure(e.message));
    } on BullBitcoinApiMinAmountException catch (e) {
      // The two amount bounds are expected user input errors, so they are
      // logged at info rather than severe; the bound itself travels in the
      // failure so the screen can name it.
      log.info('Buy order below the minimum: ${e.message}');
      return Err(
        BuyBelowMinAmountFailure(
          minAmount: e.minAmount,
          currency: e.currency,
          logMessage: e.message,
        ),
      );
    } on BullBitcoinApiMaxAmountException catch (e) {
      log.info('Buy order above the maximum: ${e.message}');
      return Err(
        BuyAboveMaxAmountFailure(
          maxAmount: e.maxAmount,
          currency: e.currency,
          logMessage: e.message,
        ),
      );
    } catch (e, st) {
      log.severe(message: 'Failed to place the buy order', error: e, trace: st);
      return Err(BuyUnexpectedFailure('$e'));
    }
  }
}
