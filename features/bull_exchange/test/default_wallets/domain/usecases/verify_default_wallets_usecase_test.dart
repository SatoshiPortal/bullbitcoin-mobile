import 'package:bull_exchange/src/default_wallets/domain/usecases/verify_default_wallets_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'default_wallets_usecase_test_support.dart';

void main() {
  test('reconciles the journal, then reads the wallets', () async {
    final calls = <String>[];
    final journal = InMemoryUnknownWriteJournal();
    final _ = await journal.record(
      UnknownWriteDraft(
        kind: UnknownWriteKind.defaultWalletSave,
        environment: dwSession.environment,
        request: const {'walletType': 'bitcoin', 'address': 'bc1q'},
      ),
    );
    final read = await VerifyDefaultWalletsUsecase(
      exchangeForTesting(
        access: fixedAccessForTesting(const ExchangeAccessSignedIn(dwSession)),
        unknownWrites: journal,
        readSessionPoint: () async =>
            const Ok((environment: ExchangeEnvironment.mainnet, epoch: 1)),
        getDefaultWallets: () async {
          calls.add('read');
          return const Ok(dwSaved);
        },
      ),
    ).execute(dwSession);
    // The reconcile's re-read of the saved wallet, then the read.
    expect(calls, ['read', 'read']);
    expect((read as Ok<DefaultWallets, ExchangeReadFailure>).value, dwSaved);
  });

  test('a journal that cannot be reconciled still reads', () async {
    final read = await VerifyDefaultWalletsUsecase(
      exchangeForTesting(
        access: fixedAccessForTesting(const ExchangeAccessSignedIn(dwSession)),
        unknownWrites: _UnreadableJournal(),
        getDefaultWallets: () async => const Ok(dwSaved),
      ),
    ).execute(dwSession);
    expect((read as Ok<DefaultWallets, ExchangeReadFailure>).value, dwSaved);
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
    expect(
      read,
      isA<Err<DefaultWallets, ExchangeReadFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeSessionRejectedFailure>(),
      ),
    );
    expect(reads, 0);
  });
}

final class _UnreadableJournal implements UnknownWriteJournal {
  @override
  Future<Result<UnknownWrite, ExchangeJournalFailure>> record(
    UnknownWriteDraft draft,
  ) async => const Err(ExchangeJournalFailure('unreadable'));

  @override
  Future<Result<List<UnknownWrite>, ExchangeJournalFailure>> open(
    ExchangeEnvironment environment,
  ) async => const Err(ExchangeJournalFailure('unreadable'));

  @override
  Future<Result<void, ExchangeJournalFailure>> settle(
    String id,
    UnknownWriteSettlement settlement,
  ) async => const Err(ExchangeJournalFailure('unreadable'));
}
