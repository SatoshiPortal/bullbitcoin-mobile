import 'package:exchange/exchange.dart';
import 'package:test/test.dart';

const _session = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 's-1',
);

void main() {
  for (final isIOS in [false, true]) {
    for (final superuser in [false, true]) {
      for (final connected in [false, true]) {
        test('iOS=$isIOS superuser=$superuser connected=$connected', () {
          final ExchangeAccess access = connected
              ? const ExchangeAccessSignedIn(_session)
              : const ExchangeAccessSignedOut(ExchangeEnvironment.mainnet);
          final allowed = ExchangeAvailability.platformAllowed(
            isIOS ? ExchangePlatform.ios : ExchangePlatform.other,
            isSuperuser: superuser,
          );
          expect(allowed, !isIOS || superuser);
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

  test('every access state has an availability', () {
    const table = <(ExchangeAccess, (ExchangeAvailability, bool, bool))>[
      (
        ExchangeAccessResolving(),
        (ExchangeAvailability.unavailable, false, false),
      ),
      (
        ExchangeAccessUnreadable(),
        (ExchangeAvailability.unavailable, false, false),
      ),
      (ExchangeAccessDisabled(), (ExchangeAvailability.hidden, false, false)),
      (
        ExchangeAccessSignOutIncomplete(),
        (ExchangeAvailability.hidden, false, false),
      ),
      (
        ExchangeAccessSignedOut(ExchangeEnvironment.testnet),
        (ExchangeAvailability.signInRequired, false, true),
      ),
      (
        ExchangeAccessSignedIn(_session),
        (ExchangeAvailability.ready, true, true),
      ),
      (
        ExchangeAccessExpiring(_session),
        (ExchangeAvailability.unavailable, false, true),
      ),
      (
        ExchangeAccessCredentialUnreadable(ExchangeEnvironment.mainnet),
        (ExchangeAvailability.unavailable, false, false),
      ),
    ];
    for (final (access, (availability, manage, authenticate)) in table) {
      expect(
        ExchangeAvailability.resolve(platformAllowed: true, access: access),
        availability,
        reason: '$access',
      );
      expect(
        ExchangeAvailability.resolve(platformAllowed: false, access: access),
        ExchangeAvailability.hidden,
      );
      expect(ExchangeAvailability.canManageAccount(access), manage);
      expect(ExchangeAvailability.canAuthenticate(access), authenticate);
    }
  });
}
