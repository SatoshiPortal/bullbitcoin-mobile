import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/exchange_failure.dart';

@immutable
sealed class OutcomeWatchEvent<O> {
  const OutcomeWatchEvent();
}

/// The poll with [ticket] of [orderId] answered [read].
final class WatchPolled<O> extends OutcomeWatchEvent<O> {
  final String orderId;
  final int ticket;
  final Result<O, ExchangeReadFailure> read;

  const WatchPolled(this.orderId, this.ticket, this.read);
}

/// The outcome screen became visible or stopped being visible (app in the
/// background, another route on top).
final class WatchVisibilityChanged<O> extends OutcomeWatchEvent<O> {
  final bool visible;

  const WatchVisibilityChanged({required this.visible});
}

final class WatchDeadlinePassed<O> extends OutcomeWatchEvent<O> {
  final String orderId;

  const WatchDeadlinePassed(this.orderId);
}

final class WatchReceiptOpened<O> extends OutcomeWatchEvent<O> {
  const WatchReceiptOpened();
}

final class WatchReceiptClosed<O> extends OutcomeWatchEvent<O> {
  const WatchReceiptClosed();
}

final class WatchRetryPressed<O> extends OutcomeWatchEvent<O> {
  const WatchRetryPressed();
}

final class WatchLeavePressed<O> extends OutcomeWatchEvent<O> {
  const WatchLeavePressed();
}
