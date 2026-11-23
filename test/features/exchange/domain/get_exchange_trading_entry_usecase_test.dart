import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cases = <(ExchangeAccess, ExchangeAvailability)>[
    (ExchangeAccessResolving(), ExchangeAvailability.unavailable),
    (ExchangeAccessUnreadable(), ExchangeAvailability.unavailable),
    (ExchangeAccessSignOutIncomplete(), ExchangeAvailability.hidden),
    (ExchangeAccessDisabled(), ExchangeAvailability.hidden),
    (
      ExchangeAccessEnabled(ExchangeAccessSession.unreadable),
      ExchangeAvailability.unavailable,
    ),
    (
      ExchangeAccessEnabled(ExchangeAccessSession.signedOut),
      ExchangeAvailability.signInRequired,
    ),
    (
      ExchangeAccessEnabled(ExchangeAccessSession.signedIn),
      ExchangeAvailability.ready,
    ),
  ];
  for (final (access, expected) in cases) {
    test('$access maps to $expected when platform allows access', () {
      expect(
        ExchangeAvailability.resolve(platformAllowed: true, access: access),
        expected,
      );
    });
    test('$access is hidden when platform disallows access', () {
      expect(
        ExchangeAvailability.resolve(platformAllowed: false, access: access),
        ExchangeAvailability.hidden,
      );
    });
  }
}
