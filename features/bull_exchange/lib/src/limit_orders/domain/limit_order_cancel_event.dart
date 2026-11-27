import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

@immutable
sealed class LimitCancelEvent {
  const LimitCancelEvent();
}

/// The user confirmed the cancel dialog.
final class CancelPressed extends LimitCancelEvent {
  const CancelPressed();
}

final class CancelAnswered extends LimitCancelEvent {
  final int attempt;
  final Result<LimitOrder, ExchangeGatedWriteFailure> answer;

  const CancelAnswered(this.attempt, this.answer);
}

final class CancelChecked extends LimitCancelEvent {
  final int attempt;
  final Result<LimitOrder, ExchangeReadFailure> read;

  const CancelChecked(this.attempt, this.read);
}

final class CancelRetryPressed extends LimitCancelEvent {
  const CancelRetryPressed();
}
