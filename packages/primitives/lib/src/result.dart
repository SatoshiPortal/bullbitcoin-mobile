import 'package:primitives/src/failure.dart';

/// The project-canonical result type (issue #1895). Exact shape — do NOT add
/// methods the branch lacks (no `isOk`/`getOrElse`/`flatMap`).
///
/// Success-with-no-value uses `Result<Null, F>` + `return const Ok(null)`.
/// Annotate every Result-returning method `@useResult` (`package:meta`).
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
