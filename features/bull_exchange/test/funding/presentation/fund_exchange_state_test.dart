import 'package:bull_exchange/src/funding/presentation/fund_exchange_bloc.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

UserSummary _summary(String? currency) => UserSummary(
  userNumber: 1,
  groups: const [],
  profile: const UserProfile(firstName: 'Sat', lastName: 'Oshi'),
  email: 'sat@example.com',
  balances: const [],
  currency: currency,
  dca: const UserDca(isActive: false),
  autoBuy: const UserAutoBuy(
    isActive: false,
    addresses: UserAutoBuyAddresses(),
  ),
);

void main() {
  group('initialFundingJurisdiction follows the account currency', () {
    final cases = <(String?, Jurisdiction)>[
      ('CAD', Jurisdiction.canada),
      ('EUR', Jurisdiction.europe),
      ('MXN', Jurisdiction.mexico),
      ('CRC', Jurisdiction.costaRica),
      ('USD', Jurisdiction.costaRica),
      ('ARS', Jurisdiction.argentina),
      ('COP', Jurisdiction.colombia),
      // No market yet: the catalog's legacy fallback, until fund is rebuilt.
      (null, Jurisdiction.canada),
      ('JPY', Jurisdiction.canada),
    ];
    for (final (currency, jurisdiction) in cases) {
      test('$currency -> ${jurisdiction.name}', () {
        expect(
          FundExchangeState(userSummary: _summary(currency))
              .initialFundingJurisdiction,
          jurisdiction,
        );
      });
    }
  });
}
