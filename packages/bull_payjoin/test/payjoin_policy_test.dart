import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  test('defaults preserve the current package policy', () {
    final policy = PayjoinPolicy.defaults();

    expect(policy.enabled, isFalse);
    expect(policy.minimumAmount, Sats.fromInt(10000));
    expect(policy.sessionLifetime, const Duration(hours: 24));
  });

  test('rejects a minimum amount outside policy bounds', () {
    expect(
      () => PayjoinPolicy(
        enabled: true,
        minimumAmount: Sats.fromInt(999),
        sessionLifetime: const Duration(minutes: 1),
      ),
      throwsArgumentError,
    );
  });

  test('rejects a session lifetime outside protocol bounds', () {
    expect(
      () => PayjoinPolicy(
        enabled: true,
        minimumAmount: Sats.fromInt(1000),
        sessionLifetime: const Duration(seconds: 59),
      ),
      throwsArgumentError,
    );
  });

  test('rejects a fractional-second session lifetime', () {
    expect(
      () => PayjoinPolicy(
        enabled: true,
        minimumAmount: Sats.fromInt(1000),
        sessionLifetime: const Duration(seconds: 60, milliseconds: 1),
      ),
      throwsArgumentError,
    );
  });
}
