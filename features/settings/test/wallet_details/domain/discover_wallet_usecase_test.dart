import 'package:flutter_test/flutter_test.dart';

import 'package/primitives/primitives.dart';

import 'package:settings/src/wallet_details/domain/discover_wallet_usecase.dart';
import 'package:settings/src/wallet_details/domain/wallet_details_failure.dart';

void main() {
  test('passes a successful discovery through', () async {
    final requested = <String>[];
    final usecase = DiscoverWalletUsecase((walletId) async {
      requested.add(walletId);
      return const Ok(null);
    });

    expect(
      await usecase.execute('wallet-1'),
      isA<Ok<void, WalletDetailsFailure>>(),
    );
    expect(requested, ['wallet-1']);
  });

  for (final failure in [
    const WalletDetailsUnavailableFailure('sync'),
    const WalletDetailsNotFoundFailure(),
  ]) {
    test('maps any discovery failure to its own family', () async {
      final usecase = DiscoverWalletUsecase((_) async => Err(failure));

      final result = await usecase.execute('wallet-1');

      expect(switch (result) {
        Err(:final failure) => failure,
        Ok() => fail('expected a failure'),
      }, isA<WalletDetailsDiscoveryFailure>());
    });
  }
}
