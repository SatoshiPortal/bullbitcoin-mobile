import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

final class _TestFailure extends Failure {
  const _TestFailure([super.logMessage]);
}

final class _OtherFailure extends Failure {
  const _OtherFailure([super.logMessage]);
}

void main() {
  test('fold dispatches Ok and Err', () {
    const Result<int, _TestFailure> ok = Ok(42);
    const Result<int, _TestFailure> err = Err(_TestFailure('boom'));

    expect(ok.fold((value) => 'ok:$value', (_) => 'err'), 'ok:42');
    expect(
      err.fold((value) => 'ok:$value', (failure) => failure.logMessage),
      'boom',
    );
  });

  test('map transforms only success values', () {
    const Result<int, _TestFailure> ok = Ok(2);
    const failure = _TestFailure('failure');
    const Result<int, _TestFailure> err = Err(failure);

    expect((ok.map((value) => value * 10) as Ok).value, 20);
    expect((err.map((value) => value * 10) as Err).failure, same(failure));
  });

  test('mapErr transforms only failures', () {
    const Result<int, _TestFailure> err = Err(_TestFailure('original'));
    final mapped = err.mapErr<_OtherFailure>(
      (failure) => _OtherFailure(failure.logMessage),
    );

    expect(mapped, isA<Err<int, _OtherFailure>>());
    expect((mapped as Err).failure.logMessage, 'original');
  });
}
