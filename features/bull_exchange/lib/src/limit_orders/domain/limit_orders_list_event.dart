import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'limit_orders_list_state.dart';

@immutable
sealed class LimitOrdersListEvent {
  const LimitOrdersListEvent();
}

final class ListLoaded extends LimitOrdersListEvent {
  final int attempt;
  final Result<List<LimitOrder>, ExchangeReadFailure> read;

  const ListLoaded(this.attempt, this.read);
}

/// A limit-order notification, the dashboard's refresh, or a return from
/// a create or details that changed something.
final class ListRefreshRequested extends LimitOrdersListEvent {
  const ListRefreshRequested();
}

final class ListRetryPressed extends LimitOrdersListEvent {
  const ListRetryPressed();
}

/// The user confirmed the cancel-all dialog.
final class ListCancelAllPressed extends LimitOrdersListEvent {
  const ListCancelAllPressed();
}

final class ListCancelAllAnswered extends LimitOrdersListEvent {
  final int attempt;
  final LimitCancelAllAnswer answer;

  const ListCancelAllAnswered(this.attempt, this.answer);
}
