import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

const _testSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'test',
);

void main() {
  const cases = <(ExchangeAccess, ExchangeAvailability)>[
    (ExchangeAccessResolving(), ExchangeAvailability.unavailable),
    (ExchangeAccessUnreadable(), ExchangeAvailability.unavailable),
    (ExchangeAccessSignOutIncomplete(), ExchangeAvailability.hidden),
    (ExchangeAccessDisabled(), ExchangeAvailability.hidden),
    (
      ExchangeAccessCredentialUnreadable(ExchangeEnvironment.mainnet),
      ExchangeAvailability.unavailable,
    ),
    (
      ExchangeAccessSignedOut(ExchangeEnvironment.mainnet),
      ExchangeAvailability.signInRequired,
    ),
    (ExchangeAccessSignedIn(_testSession), ExchangeAvailability.ready),
    (ExchangeAccessExpiring(_testSession), ExchangeAvailability.unavailable),
  ];
  for (final (access, expected) in cases) {
    test('$access maps to $expected when platform allows access', () {
      expect(
        ExchangeAvailability.resolve(platformAllowed: true, access: access),
        expected,
      );
    });
    test('$access is website-only when platform disallows access', () {
      expect(
        ExchangeAvailability.resolve(platformAllowed: false, access: access),
        ExchangeAvailability.websiteOnly,
      );
    });
  }
}
