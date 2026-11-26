import 'package:exchange/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:primitives/primitives.dart' show BitcoinNetwork, BitcoinUnit;

import 'dart:async';

import 'package:preferences/preferences.dart';
import 'package:swaps/swaps.dart' show SwapStore;
import 'package:transactions/testing.dart';
import 'package:sync/sync.dart'
    show WalletKey, WalletLifecycle, WalletRevision, WalletRevisionState;
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Settings extends Mock implements Preferences {}

class _Swaps extends Fake implements SwapStore {}

class _Payjoins extends Fake implements PayjoinSessions {}

class _Orders extends Fake implements OrdersRepository {}

class _LabelOrders extends Fake implements LabelExchangeOrdersUsecase {}

class _OrderSwaps extends Fake implements GetTransactionOrderSwapsUsecase {}

class _Labels extends Fake implements RefreshTransactionLabelsUsecase {}

class _History extends Fake implements WalletTransactionRepository {
  int reads = 0;
  final walletIds = <String?>[];
  Completer<void>? pending;
  bool fail = false;

  @override
  Future<Result<List<WalletTransaction>, TransactionFailure>>
  getWalletTransactions({
    String? txId,
    String? walletId,
    String? toAddress,
    Environment? environment,
    bool sync = false,
  }) async {
    walletIds.add(walletId);
    reads++;
    await pending?.future;
    if (fail) return const Err(TransactionAggregationFailure());
    return const Ok([]);
  }
}

class _Harness {
  final history = _History();
  final finishes = StreamController<String>.broadcast();
  final revisions = StreamController<WalletRevisionState>.broadcast();
  late final TransactionsCubit cubit;

  _Harness({bool global = false}) {
    final settings = _Settings();
    when(settings.fetch).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.regtest,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      ),
    );
    cubit = TransactionsCubit(
      walletId: global ? null : 'wallet-a',
      getTransactionsUsecase: GetTransactionsUsecase(
        settingsRepository: settings,
        walletTransactionRepository: history,
        swapStore: _Swaps(),
        payjoinSessions: _Payjoins(),
        exchange: exchangeForTesting(orders: (_) => _Orders()),
        labelExchangeOrdersUsecase: _LabelOrders(),
        getTransactionOrderSwapsUsecase: _OrderSwaps(),
      ),
      refreshTransactionLabelsUsecase: _Labels(),
      watchStartedWalletSyncsUsecase: const Stream.empty(),
      watchFinishedWalletSyncsUsecase: finishes.stream,
      watchTransactionReloadsUsecase: WatchTransactionReloadsUsecase(
        walletHistoryEvents(revisions.stream),
      ),
      watchWalletRevisionsUsecase: WatchWalletRevisionsUsecase(
        walletHistoryEvents(revisions.stream),
      ),
    );
  }

  void revision(int number) => revisions.add(
    WalletRevisionState(
      stamp: WalletRevision(
        key: WalletKey(id: 'wallet-a', network: BitcoinNetwork.regtest),
        generation: 0,
        revision: number,
      ),
      lifecycle: WalletLifecycle.active,
    ),
  );

  Future<void> close() async {
    await cubit.close();
    await finishes.close();
    await revisions.close();
  }
}

void main() {
  testWidgets('finish then revision then explicit pull reads history once', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.close);
    h.finishes.add('wallet-a');
    h.revision(1);
    await tester.pump();
    await h.cubit.loadTxs();
    await tester.pump(const Duration(seconds: 4));
    expect(h.history.reads, 1);
    expect(h.history.walletIds, ['wallet-a']);
  });

  testWidgets('overlapping explicit loads share the pending history read', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.close);
    final pending = Completer<void>();
    h.history.pending = pending;
    final first = h.cubit.loadTxs();
    await tester.pump();
    final second = h.cubit.loadTxs();
    await tester.pump();
    expect(h.history.reads, 1);
    pending.complete();
    await tester.pump();
    await Future.wait([first, second]);
    expect(h.cubit.state.isSyncing, isFalse);
  });

  testWidgets('a newer writer revision during a read is not discarded', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.close);
    final pending = Completer<void>();
    h.history.pending = pending;
    final first = h.cubit.loadTxs();
    await tester.pump();
    h.revision(2);
    await tester.pump();
    final explicit = h.cubit.loadTxs();
    await tester.pump(const Duration(seconds: 4));
    expect(h.history.reads, 1, reason: 'reads must never overlap');
    h.history.pending = null;
    pending.complete();
    await tester.pump();
    await Future.wait([first, explicit]);
    await tester.pump(const Duration(seconds: 4));
    expect(h.history.reads, 2);
  });

  testWidgets('unchanged or failed sync finishes still reload and recover', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.close);
    h.history.fail = true;
    h.finishes.add('wallet-a');
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(h.history.reads, 1);
    expect(h.cubit.state.failure, isNotNull);
    h.history.fail = false;
    h.finishes.add('wallet-a');
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(h.history.reads, 2);
    expect(h.cubit.state.failure, isNull);
    h.revision(3);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(h.history.reads, 3);
  });
  testWidgets(
    'pull defers early finish and revision until the full sync settles',
    (tester) async {
      final h = _Harness();
      addTearDown(h.close);
      h.cubit.deferReloads();
      h.finishes.add('wallet-a');
      h.revision(1);
      await tester.pump();
      await tester.pump(const Duration(seconds: 8));
      expect(h.history.reads, 0);
      await h.cubit.resumeReloads();
      await tester.pump(const Duration(seconds: 4));
      expect(h.history.reads, 1);
    },
  );

  testWidgets('a pre-pull read does not replace the settled final read', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.close);
    final pending = Completer<void>();
    h.history.pending = pending;
    final initial = h.cubit.loadTxs();
    await tester.pump();
    h.cubit.deferReloads();
    h.finishes.add('wallet-a');
    h.revision(1);
    await tester.pump();
    final settled = h.cubit.resumeReloads();
    await tester.pump(const Duration(seconds: 4));
    expect(h.history.reads, 1);
    h.history.pending = null;
    pending.complete();
    await tester.pump();
    await Future.wait([initial, settled]);
    expect(h.history.reads, 2);
  });

  testWidgets(
    'close cancels deferred work and ignores a late read completion',
    (tester) async {
      final h = _Harness();
      final pending = Completer<void>();
      h.history.pending = pending;
      final initial = h.cubit.loadTxs();
      await tester.pump();
      h.revision(2);
      await tester.pump();
      final state = h.cubit.state;
      await tester.runAsync(h.close);
      pending.complete();
      await tester.pump(const Duration(seconds: 4));
      await initial;
      await h.cubit.loadTxs();
      expect(h.history.reads, 1);
      expect(identical(h.cubit.state, state), isTrue);
    },
  );

  testWidgets('a global invalidation during a read is also retained', (
    tester,
  ) async {
    final h = _Harness(global: true);
    addTearDown(h.close);
    final pending = Completer<void>();
    h.history.pending = pending;
    final first = h.cubit.loadTxs();
    await tester.pump();
    h.revision(1);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(h.history.reads, 1);
    h.history.pending = null;
    pending.complete();
    await tester.pump();
    await first;
    expect(h.history.reads, 2);
    expect(h.history.walletIds, [null, null]);
  });
}
