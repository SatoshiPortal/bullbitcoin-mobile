import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/exchange_failure.dart';
import '../domain/exchange_write_gate.dart';
import 'server_confirm_state.dart';

@immutable
sealed class ServerConfirmEvent<T, C> {
  const ServerConfirmEvent();
}

/// What the write gate and the write of [attempt] answered.
final class ConfirmAnswered<T, C> extends ServerConfirmEvent<T, C> {
  final int attempt;
  final GatedWrite<Result<C, ExchangeWriteFailure>> answer;

  const ConfirmAnswered(this.attempt, this.answer);
}

final class ConfirmVerified<T, C> extends ServerConfirmEvent<T, C> {
  final int attempt;
  final ConfirmCheck<C> check;

  const ConfirmVerified(this.attempt, this.check);
}

final class ConfirmCommitPressed<T, C> extends ServerConfirmEvent<T, C> {
  const ConfirmCommitPressed();
}

final class ConfirmRetryPressed<T, C> extends ServerConfirmEvent<T, C> {
  const ConfirmRetryPressed();
}

final class ConfirmBackPressed<T, C> extends ServerConfirmEvent<T, C> {
  const ConfirmBackPressed();
}
