import 'package:exchange/exchange.dart';
import 'package:test/test.dart';

const _session = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 's-1',
);

void main() {
  group('ExchangePlatform.websiteOnly: iOS without superuser only', () {
    const table = <(ExchangePlatform, bool, bool)>[
      (ExchangePlatform.ios, false, true),
      (ExchangePlatform.ios, true, false),
      (ExchangePlatform.other, false, false),
      (ExchangePlatform.other, true, false),
    ];
    for (final (platform, superuser, websiteOnly) in table) {
      test('$platform superuser=$superuser', () {
        expect(platform.websiteOnly(isSuperuser: superuser), websiteOnly);
        expect(
          ExchangeAvailability.platformAllowed(
            platform,
            isSuperuser: superuser,
          ),
          !websiteOnly,
        );
      });
    }
    test('every platform is in the table', () {
      expect(table.map((row) => row.$1).toSet(), ExchangePlatform.values);
    });
  });

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
                ? ExchangeAvailability.websiteOnly
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
        ExchangeAvailability.websiteOnly,
      );
      expect(ExchangeAvailability.canManageAccount(access), manage);
      expect(ExchangeAvailability.canAuthenticate(access), authenticate);
    }
  });
}
