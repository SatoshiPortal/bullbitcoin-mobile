import 'package:bb_mobile/features/exchange/domain/exchange_access.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_availability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final isIOS in [false, true]) {
    for (final superuser in [false, true]) {
      for (final connected in [false, true]) {
        test('iOS=$isIOS superuser=$superuser connected=$connected', () {
          final access = ExchangeAccessEnabled(
            connected
                ? ExchangeAccessSession.signedIn
                : ExchangeAccessSession.signedOut,
          );
          final allowed = !isIOS || superuser;
          expect(
            ExchangeAvailability.resolve(
              platformAllowed: allowed,
              access: access,
            ),
            !allowed
                ? ExchangeAvailability.hidden
                : connected
                ? ExchangeAvailability.ready
                : ExchangeAvailability.signInRequired,
          );
          expect(ExchangeAvailability.canManageAccount(access), connected);
          expect(ExchangeAvailability.canAuthenticate(access), isTrue);
        });
      }
    }
  }
  test('unreadable and pending cleanup never allow account authentication', () {
    for (final access in <ExchangeAccess>[
      const ExchangeAccessResolving(),
      const ExchangeAccessDisabled(),
      const ExchangeAccessUnreadable(),
      const ExchangeAccessSignOutIncomplete(),
      const ExchangeAccessEnabled(ExchangeAccessSession.unreadable),
    ]) {
      expect(ExchangeAvailability.canManageAccount(access), isFalse);
      expect(ExchangeAvailability.canAuthenticate(access), isFalse);
    }
  });
}
