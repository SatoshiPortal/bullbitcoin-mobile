import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/exchange_failure.dart';
import '../domain/exchange_write_gate.dart';

@immutable
sealed class OrderStepEvent<R, O> {
  const OrderStepEvent();
}

/// What the write gate and the create of [attempt] answered.
final class OrderCreateAnswered<R, O> extends OrderStepEvent<R, O> {
  final int attempt;
  final GatedWrite<Result<O, ExchangeWriteFailure>> answer;

  const OrderCreateAnswered(this.attempt, this.answer);
}

/// The re-read after an unknown create of [attempt]: [Ok] is the
/// matching order, [ExchangeMissingFailure] means no order matched, which cannot prove
/// the create did not happen.
final class OrderFindAnswered<R, O> extends OrderStepEvent<R, O> {
  final int attempt;
  final Result<O, ExchangeReadFailure> read;

  const OrderFindAnswered(this.attempt, this.read);
}

final class OrderLockDue<R, O> extends OrderStepEvent<R, O> {
  final String orderId;

  const OrderLockDue(this.orderId);
}

final class OrderRefreshed<R, O> extends OrderStepEvent<R, O> {
  final String orderId;
  final Result<O, ExchangeReadFailure> read;

  const OrderRefreshed(this.orderId, this.read);
}

final class OrderRetryDue<R, O> extends OrderStepEvent<R, O> {
  final String orderId;

  const OrderRetryDue(this.orderId);
}

final class OrderRetryPressed<R, O> extends OrderStepEvent<R, O> {
  const OrderRetryPressed();
}

final class OrderCommitPressed<R, O> extends OrderStepEvent<R, O> {
  const OrderCommitPressed();
}

final class OrderBackPressed<R, O> extends OrderStepEvent<R, O> {
  const OrderBackPressed();
}
