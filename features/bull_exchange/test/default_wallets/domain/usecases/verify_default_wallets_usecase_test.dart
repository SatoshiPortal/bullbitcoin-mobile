import 'package:bull_exchange/src/default_wallets/domain/usecases/verify_default_wallets_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'default_wallets_usecase_test_support.dart';

void main() {
  test('reconciles the journal, then reads the wallets', () async {
    final calls = <String>[];
    final read = await VerifyDefaultWalletsUsecase(
      exchangeForTesting(
        access: fixedAccessForTesting(const ExchangeAccessSignedIn(dwSession)),
        unknownWrites: InMemoryUnknownWriteJournal(),
        readSessionPoint: () async {
          calls.add('session point');
          return const Ok((environment: ExchangeEnvironment.mainnet, epoch: 1));
        },
        getDefaultWallets: () async {
          calls.add('read');
          return const Ok(dwSaved);
        },
      ),
    ).execute(dwSession);
    expect(calls, ['session point', 'read']);
    expect((read as ReadGot<DefaultWallets>).value, dwSaved);
  });

  test('a journal that cannot be reconciled still reads', () async {
    final read = await VerifyDefaultWalletsUsecase(
      exchangeForTesting(
        access: fixedAccessForTesting(const ExchangeAccessSignedIn(dwSession)),
        unknownWrites: InMemoryUnknownWriteJournal(),
        readSessionPoint: () async =>
            const Err(ExchangeNetworkFailure('offline')),
        getDefaultWallets: () async => const Ok(dwSaved),
      ),
    ).execute(dwSession);
    expect((read as ReadGot<DefaultWallets>).value, dwSaved);
  });

  test('the read for another session is never sent', () async {
    var reads = 0;
    final read = await VerifyDefaultWalletsUsecase(
      exchangeForTesting(
        access: fixedAccessForTesting(const ExchangeAccessSignedIn(dwSession)),
        getDefaultWallets: () async {
          reads++;
          return const Ok(dwSaved);
        },
      ),
    ).execute(dwOtherSession);
    expect(read, isA<ReadSessionRejected<DefaultWallets>>());
    expect(reads, 0);
  });
}
