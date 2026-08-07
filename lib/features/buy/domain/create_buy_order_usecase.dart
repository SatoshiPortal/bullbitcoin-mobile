import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/buy_error.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
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
  Future<BuyOrder> execute({
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
        Ok(:final value) => value.enabled,
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
              // The URI cannot be revised after order placement, so the
              // exchange payout uses the protocol maximum lifetime.
              expiresAt: DateTime.now().add(
                PayjoinPolicy.maximumSessionLifetime,
              ),
            ),
          );
          final receiver = switch (result) {
            Ok(:final value) => value,
            Err() => throw StateError('Failed to start Payjoin receiver'),
          };
          payjoinId = receiver.id;
          payjoinBip21 = receiver.pjUri;
        } catch (e) {
          // Payjoin is an improvement on a purchase, never a precondition for
          // one. Anything that stops a session from opening — no spendable
          // utxo, a relay outage, a wallet that cannot sign — falls back to the
          // plain address the flow has always used.
          log.warning('Buy order falls back to a plain address: $e');
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
        return orderWithPayjoin;
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
    } on BuyError {
      rethrow;
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      throw BuyError.unexpected(message: '$e');
    }
  }
}
