import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

final class _TestFailure extends Failure {
  const _TestFailure([super.logMessage]);
}

final class _OtherFailure extends Failure {
  const _OtherFailure([super.logMessage]);
}

void main() {
  group('Result.fold', () {
    test('Ok runs onOk with the value', () {
      const Result<int, _TestFailure> r = Ok(42);
      expect(r.fold((v) => 'ok:$v', (f) => 'err'), 'ok:42');
    });

    test('Err runs onErr with the failure', () {
      const Result<int, _TestFailure> r = Err(_TestFailure('boom'));
      expect(r.fold((v) => 'ok', (f) => 'err:${f.logMessage}'), 'err:boom');
    });
  });

  group('Result.map', () {
    test('Ok transforms the value', () {
      const Result<int, _TestFailure> r = Ok(2);
      final mapped = r.map((v) => v * 10);
      expect((mapped as Ok).value, 20);
    });

    test('Err passes the failure through untouched', () {
      const failure = _TestFailure('x');
      const Result<int, _TestFailure> r = Err(failure);
      final mapped = r.map((v) => v * 10);
      expect((mapped as Err).failure, same(failure));
    });
  });

  group('Result.mapErr', () {
    test('Err transforms the failure type', () {
      const Result<int, _TestFailure> r = Err(_TestFailure('orig'));
      final mapped = r.mapErr<_OtherFailure>((f) => _OtherFailure(f.logMessage));
      expect(mapped, isA<Err<int, _OtherFailure>>());
      expect((mapped as Err).failure.logMessage, 'orig');
    });

    test('Ok keeps the value, changes only the failure type param', () {
      const Result<int, _TestFailure> r = Ok(7);
      final mapped = r.mapErr<_OtherFailure>((f) => const _OtherFailure());
      expect(mapped, isA<Ok<int, _OtherFailure>>());
      expect((mapped as Ok).value, 7);
    });
  });

  test('success-with-no-value convention compiles', () {
    const Result<Null, _TestFailure> r = Ok(null);
    expect((r as Ok).value, isNull);
  });
}
