import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'limit_order_cancel_event.dart';

@immutable
sealed class LimitDetailsEvent {
  const LimitDetailsEvent();
}

final class DetailsLoaded extends LimitDetailsEvent {
  final int attempt;
  final Result<LimitOrder, ExchangeReadFailure> read;

  const DetailsLoaded(this.attempt, this.read);
}

/// Retry of a failed read, or Check again of an unverified cancel.
final class DetailsRetryPressed extends LimitDetailsEvent {
  const DetailsRetryPressed();
}

final class DetailsCancelChanged extends LimitDetailsEvent {
  final LimitCancelEvent event;

  const DetailsCancelChanged(this.event);
}

/// App bar, system Back or Done.
final class DetailsBackPressed extends LimitDetailsEvent {
  const DetailsBackPressed();
}

final class DetailsSessionChanged extends LimitDetailsEvent {
  final ExchangeSession? session;

  const DetailsSessionChanged(this.session);
}
