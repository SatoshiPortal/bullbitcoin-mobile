import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/features/send/public/send_facade.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/delete_wallet_pending_transaction_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_pending_transactions_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSendFacade extends Mock implements SendFacade {}

void main() {
  late _MockSendFacade sendFacade;

  setUp(() => sendFacade = _MockSendFacade());

  test('maps pending transaction stream failures to Wallet', () async {
    when(
      () => sendFacade.watchPending('wallet'),
    ).thenAnswer((_) => Stream.value(const Err(SendPersistenceFailure())));
    final usecase = WatchWalletPendingTransactionsUsecase(sendFacade);

    final result = await usecase.execute('wallet').first;

    expect(
      result,
      isA<Err<PendingBitcoinTransactionSnapshot, WalletFailure>>(),
    );
    expect(
      (result as Err).failure,
      isA<WalletPendingTransactionsLoadFailure>(),
    );
  });

  test('maps pending transaction delete failures to Wallet', () async {
    final transaction = PendingBitcoinTransaction(
      id: 'transaction',
      walletId: 'wallet',
      stage: PendingBitcoinTransactionStage.draft,
      recipient: '',
      amount: '',
      amountCurrencyCode: '',
      sendMax: false,
      feeSelection: FeeSelection.fastest,
      replaceByFee: true,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    when(
      () => sendFacade.deletePending(transaction),
    ).thenAnswer((_) async => const Err(SendPersistenceFailure()));
    final usecase = DeleteWalletPendingTransactionUsecase(sendFacade);

    final result = await usecase.execute(transaction);

    expect(result, isA<Err<void, WalletFailure>>());
    expect(
      (result as Err).failure,
      isA<WalletPendingTransactionDeleteFailure>(),
    );
  });
}
