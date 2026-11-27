import 'dart:async';

import 'package:bull_exchange/src/orders/domain/usecases/get_order_usecase.dart';
import 'package:bull_exchange/src/payin/domain/usecases/build_payin_usecase.dart';
import 'package:bull_exchange/src/payin/domain/usecases/check_transaction_seen_usecase.dart';
import 'package:bull_exchange/src/payin/domain/usecases/retry_payjoin_proposal_usecase.dart';
import 'package:bull_exchange/src/payin/domain/usecases/send_payin_usecase.dart';
import 'package:bull_exchange/src/payin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bull_exchange/src/payin/outcome_watch_runner.dart';
import 'package:bull_exchange/src/payin/payin_spend_calls.dart';
import 'package:clock/clock.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';

/// The wallet's signed spend the payin machine carries (its `P`): what a
/// payin to the order's deposit sends. Opaque to the machine.
sealed class PayinSpend {
  const PayinSpend();
}

/// A signed on-chain transaction, broadcast by the wallet.
final class SignedBitcoinPayin<S> extends PayinSpend {
  final S signed;

  const SignedBitcoinPayin(this.signed);
}

/// A signed Liquid transaction, broadcast by the wallet.
final class SignedLiquidPayin<S> extends PayinSpend {
  final S signed;

  const SignedLiquidPayin(this.signed);
}

/// A prepared on-chain spend handed to a payjoin session on send: from then
/// on the session broadcasts the proposal or the original.
final class PayjoinPayin<S> extends PayinSpend {
  final S prepared;
  final String bip21;
  final int amountSat;
  final double feeRateSatPerVb;
  final DateTime expiresAt;

  const PayjoinPayin({
    required this.prepared,
    required this.bip21,
    required this.amountSat,
    required this.feeRateSatPerVb,
    required this.expiresAt,
  });
}

/// The use cases of a payin (sell and pay). Only [PayinRunner] calls
/// them; a flow's bloc hands them over.
final class PayinUsecases {
  final BuildPayinUsecase build;
  final SendPayinUsecase send;
  final GetOrderUsecase getOrder;
  final CheckTransactionSeenUsecase transactionSeen;
  final WatchPayjoinUsecase watchPayjoin;
  final RetryPayjoinProposalUsecase retryPayjoin;

  const PayinUsecases({
    required this.build,
    required this.send,
    required this.getOrder,
    required this.transactionSeen,
    required this.watchPayjoin,
    required this.retryPayjoin,
  });

  PayinUsecases.of(Exchange exchange, PayinWalletServices wallets)
    : this(
        build: BuildPayinUsecase(wallets.spend),
        send: SendPayinUsecase(
          exchange,
          spend: wallets.spend,
          payjoinSender: wallets.payjoinSender,
          payjoinSessions: wallets.payjoinSessions,
          labels: wallets.labels,
        ),
        getOrder: GetOrderUsecase(exchange),
        transactionSeen: CheckTransactionSeenUsecase(wallets.payjoinSessions),
        watchPayjoin: WatchPayjoinUsecase(wallets.payjoinSessions),
        retryPayjoin: RetryPayjoinProposalUsecase(wallets.payjoinSender),
      );
}

/// Runs the payin machine's effects (C4 `payin.dart`) for sell and pay,
/// with the flow's session: build, the send through the account's write
/// gate (journaled when its outcome is unknown or handed to payjoin), the
/// order re-read before any retry, the look-up after a doubtful send, the
/// payjoin session watch and the order watch. Every answer carries the
/// attempt, session id or ticket of its effect.
final class PayinRunner {
  final PayinUsecases _usecases;
  final ExchangeSession _session;
  final void Function(PayinEvent<PayinSpend> event) _emit;
  late final OutcomeWatchRunner<Order> _watch = OutcomeWatchRunner(
    (orderId) => _usecases.getOrder.execute(_session, orderId),
    (event) => _send(PayinWatchEvent(event)),
  );
  final Map<String, StreamSubscription<PayjoinProgress>> _payjoins = {};
  bool _closed = false;

  PayinRunner(this._usecases, this._session, this._emit);

  void run(List<PayinEffect<PayinSpend>> effects) {
    for (final effect in effects) {
      switch (effect) {
        case final PayinBuild<PayinSpend> build:
          _answer(
            _usecases.build
                .execute(build)
                .then((r) => PayinBuildAnswered(build.attempt, r, clock.now())),
          );
        case final PayinSend<PayinSpend> send:
          _answer(_usecases.send.execute(_session, send));
        case PayinRecheck(:final orderId, :final attempt):
          _answer(
            _usecases.getOrder
                .execute(_session, orderId)
                .then((read) => PayinRechecked(attempt, read, clock.now())),
          );
        case PayinVerify(:final order, :final attempt, :final txid):
          _answer(_verify(order.orderId, attempt, txid));
        case PayinFollowPayjoin(:final sessionId):
          unawaited(_payjoins.remove(sessionId)?.cancel());
          _payjoins[sessionId] = _usecases.watchPayjoin
              .execute(sessionId)
              .listen(
                (progress) => _send(PayinPayjoinUpdated(sessionId, progress)),
                onError: (Object _) => _send(PayinPayjoinWatchEnded(sessionId)),
                onDone: () => _send(PayinPayjoinWatchEnded(sessionId)),
                cancelOnError: true,
              );
        case PayinStopPayjoin(:final sessionId):
          unawaited(_payjoins.remove(sessionId)?.cancel());
        case PayinRetryPayjoin(:final sessionId):
          unawaited(_usecases.retryPayjoin.execute(sessionId));
        case PayinWatchEffect(:final effect):
          _watch.run(effect);
      }
    }
  }

  Future<PayinEvent<PayinSpend>> _verify(
    String orderId,
    int attempt,
    String? txid,
  ) async {
    // The look-up runs alongside the order read; null when no txid is known.
    final transaction = switch (txid) {
      null => null,
      final String txid =>
        _usecases.transactionSeen
            .execute(txid)
            .then((seen) => (txid: txid, seen: seen)),
    };
    final order = await _usecases.getOrder.execute(_session, orderId);
    return PayinVerified(
      attempt,
      payinCheckFrom(transaction: await transaction, order: order),
    );
  }

  void _answer(Future<PayinEvent<PayinSpend>> answer) =>
      unawaited(answer.then(_send));

  void _send(PayinEvent<PayinSpend> event) {
    if (!_closed) _emit(event);
  }

  void close() {
    _closed = true;
    _watch.close();
    for (final subscription in _payjoins.values) {
      unawaited(subscription.cancel());
    }
    _payjoins.clear();
  }
}
