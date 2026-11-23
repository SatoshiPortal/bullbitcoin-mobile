import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

UserSummary _summary(List<String> groups) => UserSummary(
  userNumber: 1,
  groups: groups,
  profile: const UserProfile(firstName: 'Sat', lastName: 'Oshi'),
  email: 'sat@example.com',
  balances: const [],
  dca: const UserDca(isActive: false),
  autoBuy: const UserAutoBuy(
    isActive: false,
    addresses: UserAutoBuyAddresses(),
  ),
);

void main() {
  group('KYC group names are the server ones', () {
    test('Canada light verification is KYC_CANADA_LIGHT_VERIFICATION', () {
      expect(
        _summary(['KYC_CANADA_LIGHT_VERIFICATION']).isLightKycLevel,
        isTrue,
      );
    });

    test('KYC_LIGHT_VERIFICATION does not exist on the server', () {
      expect(_summary(['KYC_LIGHT_VERIFICATION']).isLightKycLevel, isFalse);
    });
  });

  group('needsKycUpgrade follows the server limits table', () {
    // (groups, currency, amount, needs upgrade)
    final cases = <(List<String>, FiatCurrency, double, bool)>[
      // Full verification: no limits anywhere.
      (['KYC_IDENTITY_VERIFIED'], FiatCurrency.eur, 1000000, false),
      (['KYC_IDENTITY_VERIFIED'], FiatCurrency.cad, 1000000, false),
      // Canada light: CAD with no cap, nothing else.
      (['KYC_CANADA_LIGHT_VERIFICATION'], FiatCurrency.cad, 5000, false),
      (['KYC_CANADA_LIGHT_VERIFICATION'], FiatCurrency.cad, 50000, false),
      (['KYC_CANADA_LIGHT_VERIFICATION'], FiatCurrency.crc, 1000, true),
      // Canada limited: 999.99 CAD per transaction.
      (['KYC_LIMITED_VERIFICATION'], FiatCurrency.cad, 999.0, false),
      (['KYC_LIMITED_VERIFICATION'], FiatCurrency.cad, 999.99, false),
      (['KYC_LIMITED_VERIFICATION'], FiatCurrency.cad, 1000, true),
      // Limited in CR / AR: daily caps only, enforced by the server.
      (['KYC_LIMITED_VERIFICATION'], FiatCurrency.crc, 1000000, false),
      (['KYC_LIMITED_VERIFICATION'], FiatCurrency.ars, 1500000, false),
      // Limited in EU / MX / CO / US: not available.
      (['KYC_LIMITED_VERIFICATION'], FiatCurrency.eur, 10, true),
      (['KYC_LIMITED_VERIFICATION'], FiatCurrency.mxn, 10, true),
      (['KYC_LIMITED_VERIFICATION'], FiatCurrency.cop, 10, true),
      (['KYC_LIMITED_VERIFICATION'], FiatCurrency.usd, 10, true),
      // SINPE verified: CRC; missionary: ARS.
      (['KYC_SINPE_VERIFIED'], FiatCurrency.crc, 1000000, false),
      (['KYC_SINPE_VERIFIED'], FiatCurrency.cad, 10, true),
      (['MISSIONARY'], FiatCurrency.ars, 1000000, false),
      (['MISSIONARY'], FiatCurrency.cad, 10, true),
      // No KYC group.
      ([], FiatCurrency.cad, 10, true),
    ];

    for (final (groups, currency, amount, expected) in cases) {
      test('$groups ${currency.code} $amount -> $expected', () {
        expect(_summary(groups).needsKycUpgrade(amount, currency), expected);
      });
    }
  });
}
