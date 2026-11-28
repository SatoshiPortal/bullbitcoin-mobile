import 'package:transactions/testing.dart';

import 'dart:async';

import 'package:primitives/primitives.dart' show BitcoinNetwork, Ok;
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class Read extends Mock implements GetTransactionsUsecase {}

class Labels extends Mock implements RefreshTransactionLabelsUsecase {}

// Direct synchronization finishes are current public wallet IDs.
void main() {
  testWidgets('direct failed sync invalidates aborted standalone payjoin', (
    tester,
  ) async {
    final read = Read();
    final labels = Labels();
    final finishes = StreamController<String>.broadcast();
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
    when(() => read.execute(walletId: null)).thenAnswer(
      (_) async => Ok(
        TransactionHistory(
          transactions: localTransactions,
          exchangeOrders: const ExchangeOrdersMerged(),
        ),
      ),
    );
    final started = const Stream<String>.empty();
    when(() => labels.execute(any())).thenAnswer(
      (call) async => call.positionalArguments.first as List<Transaction>,
    );
    final cubit = TransactionsCubit(
      getTransactionsUsecase: read,
      refreshTransactionLabelsUsecase: labels,
      watchStartedWalletSyncsUsecase: started,
      watchFinishedWalletSyncsUsecase: finishes.stream,
      watchTransactionReloadsUsecase: WatchTransactionReloadsUsecase(
        walletHistoryEvents(
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
    finishes.add('wallet-a');
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
