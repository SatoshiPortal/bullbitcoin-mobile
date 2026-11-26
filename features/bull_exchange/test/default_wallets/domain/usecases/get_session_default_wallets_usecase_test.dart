import 'package:bull_exchange/src/default_wallets/domain/usecases/get_session_default_wallets_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'default_wallets_usecase_test_support.dart';

void main() {
  test('reads the default wallets of the current session', () async {
    final read = await GetSessionDefaultWalletsUsecase(
      exchangeForTesting(
        access: fixedAccessForTesting(const ExchangeAccessSignedIn(dwSession)),
        getDefaultWallets: () async => const Ok(dwSaved),
      ),
    ).execute(dwSession);
    expect((read as ReadGot<DefaultWallets>).value, dwSaved);
  });

  test('a read for another session is never sent', () async {
    var reads = 0;
    final read = await GetSessionDefaultWalletsUsecase(
      exchangeForTesting(
        access: fixedAccessForTesting(const ExchangeAccessSignedIn(dwSession)),
        getDefaultWallets: () async {
          reads++;
          return const Ok(dwSaved);
        },
      ),
    ).execute(dwOtherSession);
    expect(
      read,
      isA<ReadSessionRejected<DefaultWallets>>().having(
        (r) => r.why,
        'why',
        ExchangeSessionRejection.sessionChanged,
      ),
    );
    expect(reads, 0);
  });

  test('a failed read is never wallets', () async {
    final read = await GetSessionDefaultWalletsUsecase(
      exchangeForTesting(
        access: fixedAccessForTesting(const ExchangeAccessSignedIn(dwSession)),
        getDefaultWallets: () async =>
            const Err(ExchangeNetworkFailure('offline')),
      ),
    ).execute(dwSession);
    expect(read, isNot(isA<ReadGot<DefaultWallets>>()));
  });
}
