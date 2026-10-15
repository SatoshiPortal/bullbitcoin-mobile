import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  test('exchange minimum is inclusive and independent of receive settings', () {
    expect(PayjoinPolicy.allowsExchangeAmount(null), isFalse);
    expect(PayjoinPolicy.allowsExchangeAmount(0), isFalse);
    expect(PayjoinPolicy.allowsExchangeAmount(49999), isFalse);
    expect(PayjoinPolicy.allowsExchangeAmount(50000), isTrue);
    expect(PayjoinPolicy.allowsExchangeAmount(50001), isTrue);
    expect(PayjoinPolicy.defaults().minimumAmount, Sats.fromInt(10000));
  });

  test('defaults keep user payjoins off and exchange payjoins on', () {
    final policy = PayjoinPolicy.defaults();

    expect(policy.sendEnabled, isFalse);
    expect(policy.receiveEnabled, isFalse);
    expect(policy.buyEnabled, isTrue);
    expect(policy.sellEnabled, isTrue);
    expect(policy.minimumAmount, Sats.fromInt(10000));
    expect(policy.sessionLifetime, const Duration(hours: 24));
  });

  test('rejects a minimum amount outside policy bounds', () {
    expect(
      () => PayjoinPolicy(
        sendEnabled: true,
        receiveEnabled: true,
        buyEnabled: true,
        sellEnabled: true,
        minimumAmount: Sats.fromInt(999),
        sessionLifetime: const Duration(minutes: 1),
      ),
      throwsArgumentError,
    );
  });

  test('rejects a session lifetime outside protocol bounds', () {
    expect(
      () => PayjoinPolicy(
        sendEnabled: true,
        receiveEnabled: true,
        buyEnabled: true,
        sellEnabled: true,
        minimumAmount: Sats.fromInt(1000),
        sessionLifetime: const Duration(seconds: 59),
      ),
      throwsArgumentError,
    );
  });

  test('rejects a fractional-second session lifetime', () {
    expect(
      () => PayjoinPolicy(
        sendEnabled: true,
        receiveEnabled: true,
        buyEnabled: true,
        sellEnabled: true,
        minimumAmount: Sats.fromInt(1000),
        sessionLifetime: const Duration(seconds: 60, milliseconds: 1),
      ),
      throwsArgumentError,
    );
  });

  test('each action reads its own switch', () {
    final policy = PayjoinPolicy.defaults().withAction(
      PayjoinAction.receive,
      enabled: true,
    );

    expect(policy.allows(PayjoinAction.receive), isTrue);
    expect(policy.allows(PayjoinAction.send), isFalse);
    expect(policy.allows(PayjoinAction.buy), isTrue);
    expect(policy.allows(PayjoinAction.sell), isTrue);
    expect(
      PayjoinPolicy.defaults()
          .withAction(PayjoinAction.buy, enabled: false)
          .withAction(PayjoinAction.sell, enabled: false)
          .anyEnabled,
      isFalse,
    );
  });
}
