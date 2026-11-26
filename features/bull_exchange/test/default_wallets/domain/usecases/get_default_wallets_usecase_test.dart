import 'package:bull_exchange/src/default_wallets/domain/usecases/get_default_wallets_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../../dca/dca_fixtures.dart';

void main() {
  test('reads the default wallets', () async {
    final read = await GetDefaultWalletsUsecase(
      exchangeForTesting(getDefaultWallets: () async => const Ok(dcaWallets)),
    ).execute();
    expect((read as ReadGot<DefaultWallets>).value, dcaWallets);
  });

  test('a failed read is never wallets', () async {
    final read = await GetDefaultWalletsUsecase(
      exchangeForTesting(
        getDefaultWallets: () async =>
            const Err(ExchangeSessionRejectedFailure()),
      ),
    ).execute();
    expect(read, isA<ReadSessionRejected<DefaultWallets>>());
  });
}
