import 'dart:async';

import 'package:bull_exchange/src/payin/outcome_watch_runner.dart';
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

/// The calls a payin needs, bound to one session and wallet set.
typedef PayinCalls = ({
  Future<PayinBuildResult<PayinSpend>> Function(PayinBuild<PayinSpend> effect)
  build,
  Future<PayinBroadcastOutcome> Function(PayinBuilt<PayinSpend> built) send,
  Future<ExchangeRead<Order>> Function(String orderId) readOrder,

  /// Whether the source wallet or its network shows [txid]; null when it
  /// can't tell.
  Future<bool?> Function(String txid) txSeen,
  Stream<PayjoinProgress> Function(String sessionId) watchPayjoin,
  Future<void> Function(String sessionId) retryPayjoin,
  Future<void> Function(String orderId, BtcNetwork network, String? txid)
  journalUnknown,
});

/// Runs the payin machine's effects (C4 `payin.dart`) for sell and pay:
/// build, the send through the account's write gate (journaled when its
/// outcome is unknown or handed to payjoin), the order re-read before any
/// retry, the look-up after a doubtful send, the payjoin session watch and
/// the order watch. Every answer carries the attempt, session id or ticket
/// of its effect.
final class PayinRunner {
  final PayinCalls _calls;
  final ExchangeWriteGate _gate;
  final ExchangeSession _session;
  final void Function(PayinEvent<PayinSpend> event) _emit;
  late final OutcomeWatchRunner<Order> _watch = OutcomeWatchRunner(
    _calls.readOrder,
    (event) => _send(PayinWatchEvent(event)),
  );
  final Map<String, StreamSubscription<PayjoinProgress>> _payjoins = {};
  bool _closed = false;
  bool _witnessed = false;

  PayinRunner(this._calls, this._gate, this._session, this._emit);

  void useWitnessedWallet() => _witnessed = true;

  void run(List<PayinEffect<PayinSpend>> effects) {
    if (_closed) return;
    for (final effect in effects) {
      switch (effect) {
        case final PayinBuild<PayinSpend> build:
          _answer(
            _build(build)
                .then((r) => PayinBuildAnswered(build.attempt, r, clock.now())),
          );
        case final PayinSend<PayinSpend> send:
          _answer(
            runPayinSend(
              gate: _gate,
              session: _session,
              effect: send,
              now: clock.now,
              send: _calls.send,
              journalUnknown: _calls.journalUnknown,
            ),
          );
        case PayinRecheck(:final orderId, :final attempt):
          _answer(
            _calls
                .readOrder(orderId)
                .then((read) => PayinRechecked(attempt, read, clock.now())),
          );
        case PayinVerify(:final order, :final attempt, :final txid):
          _answer(_verify(order.orderId, attempt, txid));
        case PayinFollowPayjoin(:final sessionId):
          unawaited(_payjoins.remove(sessionId)?.cancel());
          _payjoins[sessionId] = _calls
              .watchPayjoin(sessionId)
              .listen(
                (progress) => _send(PayinPayjoinUpdated(sessionId, progress)),
                onError: (Object _) => _send(PayinPayjoinWatchEnded(sessionId)),
                onDone: () => _send(PayinPayjoinWatchEnded(sessionId)),
                cancelOnError: true,
              );
        case PayinStopPayjoin(:final sessionId):
          unawaited(_payjoins.remove(sessionId)?.cancel());
        case PayinRetryPayjoin(:final sessionId):
          // A persisted session ID cannot rebind a foreground attempt.
          // Leave watches/reconciliation in place after a previous handoff.
          if (!_witnessed) unawaited(_calls.retryPayjoin(sessionId));
        case PayinWatchEffect(:final effect):
          _watch.run(effect);
      }
    }
  }

  Future<PayinBuildResult<PayinSpend>> _build(
    PayinBuild<PayinSpend> effect,
  ) async {
    final attempt = effect.spend.walletAttempt;
    if (attempt == null) return _calls.build(effect);
    const refused = PayinBuildFailed<PayinSpend>(
      PayinBuildProblem.notAuthorized,
    );
    if (!attempt.isCurrent) return refused;
    final result = await _calls.build(effect);
    if (!attempt.isCurrent) return refused;
    if (result case PayinBuildOk(:final built)
        when !identical(built.spend.walletAttempt, attempt)) {
      return refused;
    }
    return result;
  }

  Future<PayinEvent<PayinSpend>> _verify(
    String orderId,
    int attempt,
    String? txid,
  ) async {
    final seen = txid == null ? Future.value(null) : _calls.txSeen(txid);
    final order = await _calls.readOrder(orderId);
    return PayinVerified(
      attempt,
      payinCheckFrom(txid: txid, txSeen: await seen, order: order),
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
