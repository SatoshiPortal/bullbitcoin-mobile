import 'package:bb_mobile/core/failures/failure.dart';

/// The outcome of a fallible operation: [Ok] with a value, or [Err] with a
/// [Failure]. Generic over the failure type so consumers never cast.
sealed class Result<T, F extends Failure> {
  const Result();

  R fold<R>(R Function(T value) onOk, R Function(F failure) onErr) =>
      switch (this) {
        Ok(:final value) => onOk(value),
        Err(:final failure) => onErr(failure),
      };

  Result<R, F> map<R>(R Function(T value) transform) => switch (this) {
    Ok(:final value) => Ok<R, F>(transform(value)),
    Err(:final failure) => Err<R, F>(failure),
  };

  /// Convert the failure type — to unify two failure domains before returning,
  /// or to lift a core failure into a feature failure.
  Result<T, G> mapErr<G extends Failure>(G Function(F failure) transform) =>
      switch (this) {
        Ok(:final value) => Ok<T, G>(value),
        Err(:final failure) => Err<T, G>(transform(failure)),
      };
}

final class Ok<T, F extends Failure> extends Result<T, F> {
  const Ok(this.value);
  final T value;
}

final class Err<T, F extends Failure> extends Result<T, F> {
  const Err(this.failure);
  final F failure;
}
