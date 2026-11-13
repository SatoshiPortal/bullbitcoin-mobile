import 'dart:async';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Ok;
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/watch_transaction_reloads_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transactions_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/refresh_transaction_labels_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';

class Read extends Mock implements GetTransactionsUsecase {}

class Labels extends Mock implements RefreshTransactionLabelsUsecase {}

class Started extends Mock implements WatchStartedWalletSyncsUsecase {}

class Finished extends Mock implements WatchFinishedWalletSyncsUsecase {}

class WalletStub extends Mock implements Wallet {}

void main() {
  testWidgets('direct failed sync invalidates aborted standalone payjoin', (
    tester,
  ) async {
    final read = Read();
    final labels = Labels();
    final started = Started();
    final finished = Finished();
    final finishes = StreamController<Wallet>.broadcast();
    final created = DateTime(2026, 11, 8);
    final pending = Transaction(
      payjoin: PayjoinReceiverSession(
        status: PayjoinStatus.proposed,
        id: 'review-session',
        network: BitcoinNetwork.mainnet,
        walletId: 'wallet-a',
        createdAt: created,
        expiresAt: created.add(const Duration(days: 1)),
        payjoinUri: 'review-uri',
        hasOriginalTransaction: true,
      ),
    );
    var localTransactions = [pending];
    when(
      () => read.execute(walletId: null),
    ).thenAnswer((_) async => Ok(localTransactions));
    when(
      () => started.execute(walletId: null),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => finished.execute(walletId: null),
    ).thenAnswer((_) => finishes.stream);
    when(() => labels.execute(any())).thenAnswer(
      (call) async => call.positionalArguments.first as List<Transaction>,
    );
    final cubit = TransactionsCubit(
      getTransactionsUsecase: read,
      refreshTransactionLabelsUsecase: labels,
      watchStartedWalletSyncsUsecase: started,
      watchFinishedWalletSyncsUsecase: finished,
      watchTransactionReloadsUsecase: WatchTransactionReloadsUsecase(
        WalletFacade(
          const Stream.empty(),
          syncFinished: finishes.stream.map((_) {}),
        ),
      ),
    );
    addTearDown(() async {
      await cubit.close();
      await finishes.close();
    });
    await cubit.loadTxs();
    expect(cubit.state.transactions, hasLength(1));
    // Fallback persisted aborted; the existing join excludes that standalone row.
    // Failed direct Electrum sync emits finished, with no native revision/pass.
    localTransactions = [];
    finishes.add(WalletStub());
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    // Returning from details invokes only this metadata refresh.
    await cubit.refreshLabels();
    expect(cubit.state.transactions, isEmpty);
    verify(() => read.execute(walletId: null)).called(2);
    await tester.pump(const Duration(seconds: 4));
    verifyNoMoreInteractions(read);
  });
}
