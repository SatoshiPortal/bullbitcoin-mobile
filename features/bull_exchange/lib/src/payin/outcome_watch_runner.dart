import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';

/// Runs an outcome watch's effects (composition §4.9) for a flow's bloc: one
/// poll timer and one deadline timer per order id; WatchStop and [close]
/// end them. Answers carry the order id and ticket of the effect, so the
/// watch drops a poll that a pause made stale.
final class OutcomeWatchRunner<O> {
  final Future<ExchangeRead<O>> Function(String orderId) _read;
  final void Function(OutcomeWatchEvent<O> event) _emit;
  final Duration _pollEvery;

  final Map<String, Timer> _polls = {};
  final Map<String, Timer> _deadlines = {};
  bool _closed = false;

  OutcomeWatchRunner(
    this._read,
    this._emit, {
    Duration pollEvery = const Duration(seconds: 5),
  }) : _pollEvery = pollEvery;

  void run(OutcomeWatchEffect effect) {
    switch (effect) {
      case WatchSchedulePoll(:final orderId, :final ticket, :final immediate):
        _polls.remove(orderId)?.cancel();
        _polls[orderId] = Timer(
          immediate ? Duration.zero : _pollEvery,
          () => unawaited(
            _read(orderId).then((read) {
              if (!_closed) _emit(WatchPolled(orderId, ticket, read));
            }),
          ),
        );
      case WatchCancelPoll(:final orderId):
        _polls.remove(orderId)?.cancel();
      case WatchStartDeadline(:final orderId, :final after):
        _deadlines.remove(orderId)?.cancel();
        _deadlines[orderId] = Timer(after, () {
          if (!_closed) _emit(WatchDeadlinePassed(orderId));
        });
      case WatchStop(:final orderId):
        _polls.remove(orderId)?.cancel();
        _deadlines.remove(orderId)?.cancel();
    }
  }

  void close() {
    _closed = true;
    for (final timer in [..._polls.values, ..._deadlines.values]) {
      timer.cancel();
    }
    _polls.clear();
    _deadlines.clear();
  }
}
