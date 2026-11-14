import 'package:primitives/primitives.dart' show BitcoinNetwork, BitcoinUnit;
import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_history_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_order_swaps_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transactions_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/label_exchange_orders_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/refresh_transaction_labels_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/watch_wallet_revisions_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/watch_transaction_reloads_usecase.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_transaction.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Settings extends Mock implements SettingsRepository {}

class _Swaps extends Fake implements SwapHistoryRepository {}

class _Payjoins extends Fake implements PayjoinSessions {}

class _Orders extends Fake implements ExchangeOrderRepository {}

class _LabelOrders extends Fake implements LabelExchangeOrdersUsecase {}

class _OrderSwaps extends Fake implements GetTransactionOrderSwapsUsecase {}

class _Labels extends Fake implements RefreshTransactionLabelsUsecase {}

class _Started extends Mock implements WatchStartedWalletSyncsUsecase {}

class _Finished extends Mock implements WatchFinishedWalletSyncsUsecase {}

class _Wallet extends Fake implements Wallet {}

class _History extends Fake implements WalletTransactionRepository {
  int reads = 0;
  final walletIds = <String?>[];
  Completer<void>? pending;
  bool fail = false;

  @override
  Future<List<WalletTransaction>> getWalletTransactions({
    String? txId,
    String? walletId,
    String? toAddress,
    Environment? environment,
    bool sync = false,
  }) async {
    walletIds.add(walletId);
    reads++;
    await pending?.future;
    if (fail) throw Exception('synthetic read failure');
    return [];
  }
}

class _Harness {
  final history = _History();
  final finishes = StreamController<Wallet>.broadcast();
  final revisions = StreamController<WalletRevisionState>.broadcast();
  late final TransactionsCubit cubit;

  _Harness({bool global = false}) {
    final settings = _Settings();
    final started = _Started();
    final finished = _Finished();
    when(settings.fetch).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.regtest,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    when(
      () => started.execute(walletId: 'wallet-a'),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => finished.execute(walletId: 'wallet-a'),
    ).thenAnswer((_) => finishes.stream);
    cubit = TransactionsCubit(
      walletId: global ? null : 'wallet-a',
      getTransactionsUsecase: GetTransactionsUsecase(
        settingsRepository: settings,
        walletTransactionRepository: history,
        boltzSwapRepository: _Swaps(),
        payjoinSessions: _Payjoins(),
        mainnetExchangeOrderRepository: _Orders(),
        testnetExchangeOrderRepository: _Orders(),
        labelExchangeOrdersUsecase: _LabelOrders(),
        getTransactionOrderSwapsUsecase: _OrderSwaps(),
      ),
      refreshTransactionLabelsUsecase: _Labels(),
      watchStartedWalletSyncsUsecase: started,
      watchFinishedWalletSyncsUsecase: finished,
      watchTransactionReloadsUsecase: WatchTransactionReloadsUsecase(
        WalletFacade(revisions.stream),
      ),
      watchWalletRevisionsUsecase: WatchWalletRevisionsUsecase(
        WalletFacade(revisions.stream),
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
    h.finishes.add(_Wallet());
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
    h.finishes.add(_Wallet());
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(h.history.reads, 1);
    expect(h.cubit.state.failure, isNotNull);
    h.history.fail = false;
    h.finishes.add(_Wallet());
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
      h.finishes.add(_Wallet());
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
    h.finishes.add(_Wallet());
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
