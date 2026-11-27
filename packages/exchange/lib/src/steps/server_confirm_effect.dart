import 'package:meta/meta.dart';

import 'server_confirm_event.dart';
import 'server_confirm_state.dart';

@immutable
sealed class ServerConfirmEffect<T> {
  const ServerConfirmEffect();
}

/// Send the write through the account's gate ([runServerConfirm]); answer
/// [ConfirmAnswered] for [attempt].
final class ConfirmSend<T> extends ServerConfirmEffect<T> {
  final T target;
  final int attempt;

  const ConfirmSend(this.target, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is ConfirmSend &&
      other.target == target &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(ConfirmSend, target, attempt);

  @override
  String toString() => 'ConfirmSend($target, $attempt)';
}

/// Re-read what the write would have changed; answer [ConfirmVerified].
final class ConfirmVerify<T> extends ServerConfirmEffect<T> {
  final T target;
  final int attempt;

  const ConfirmVerify(this.target, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is ConfirmVerify &&
      other.target == target &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(ConfirmVerify, target, attempt);

  @override
  String toString() => 'ConfirmVerify($target, $attempt)';
}
