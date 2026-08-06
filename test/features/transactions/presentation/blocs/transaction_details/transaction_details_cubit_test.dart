import 'dart:async';

import 'package:bb_mobile/core/entities/signer_entity.dart' show SignerEntity;
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/get_payjoin_by_id_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_transaction_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_order_swap_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transactions_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/watch_transaction_order_swap_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class _MockGetTransactionsByTxIdUsecase extends Mock
    implements GetTransactionsByTxIdUsecase {}

class _MockGetWalletTransactionUsecase extends Mock
    implements GetWalletTransactionUsecase {}

class _MockWatchWalletTransactionByTxIdUsecase extends Mock
    implements WatchWalletTransactionByTxIdUsecase {}

class _MockGetSwapUsecase extends Mock implements GetSwapUsecase {}

class _MockGetPayjoinByIdUsecase extends Mock
    implements GetPayjoinByIdUsecase {}

class _MockGetOrderUsecase extends Mock implements GetOrderUsecase {}

class _MockWatchSwapUsecase extends Mock implements WatchSwapUsecase {}

class _MockWatchPayjoinUsecase extends Mock implements WatchPayjoinUsecase {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

class _MockBroadcastOriginalTransactionUsecase extends Mock
    implements BroadcastOriginalTransactionUsecase {}

class _MockGetTransactionOrderSwapUsecase extends Mock
    implements GetTransactionOrderSwapUsecase {}

class _MockWatchTransactionOrderSwapUsecase extends Mock
    implements WatchTransactionOrderSwapUsecase {}

Wallet _testWallet({String origin = 'w1'}) => Wallet(
  origin: origin,
  network: Network.bitcoinMainnet,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);

WalletTransaction _walletTx({required String txId, String walletId = 'w1'}) =>
    WalletTransaction(
      walletId: walletId,
      network: Network.bitcoinMainnet,
      direction: WalletTransactionDirection.outgoing,
      status: WalletTransactionStatus.pending,
      txId: txId,
      amountSat: 50000,
      feeSat: 500,
      vsize: 150,
      inputs: const [],
      outputs: const [],
      isRbf: false,
    );

PayjoinSender _sender({
  required PayjoinStatus status,
  String? txId,
  String? proposalPsbt,
}) =>
    Payjoin.sender(
          status: status,
          uri: 'bitcoin:tb1qsender?pj=https://payjo.in',
          isTestnet: true,
          walletId: 'w1',
          originalPsbt: 'cHNidP8=',
          originalTxId: 'sender-orig-txid',
          amountSat: 50000,
          createdAt: DateTime(2026),
          expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
          txId: txId,
          proposalPsbt: proposalPsbt,
        )
        as PayjoinSender;

void main() {
  late _MockGetWalletUsecase getWallet;
  late _MockGetTransactionsByTxIdUsecase getTransactionsByTxId;
  late _MockGetWalletTransactionUsecase getWalletTransaction;
  late _MockGetPayjoinByIdUsecase getPayjoinById;
  late _MockWatchPayjoinUsecase watchPayjoin;
  late _MockWatchWalletTransactionByTxIdUsecase watchWalletTransactionByTxId;
  late _MockBroadcastOriginalTransactionUsecase broadcastOriginalTransaction;

  TransactionDetailsCubit buildCubit() => TransactionDetailsCubit(
    getWalletUsecase: getWallet,
    getTransactionsByTxIdUsecase: getTransactionsByTxId,
    getWalletTransactionUsecase: getWalletTransaction,
    getTransactionOrderSwapUsecase: _MockGetTransactionOrderSwapUsecase(),
    watchWalletTransactionByTxIdUsecase: watchWalletTransactionByTxId,
    getSwapUsecase: _MockGetSwapUsecase(),
    getPayjoinByIdUsecase: getPayjoinById,
    getOrderUsecase: _MockGetOrderUsecase(),
    watchSwapUsecase: _MockWatchSwapUsecase(),
    watchPayjoinUsecase: watchPayjoin,
    watchTransactionOrderSwapUsecase: _MockWatchTransactionOrderSwapUsecase(),
    labelsFacade: _MockLabelsFacade(),
    broadcastOriginalTransactionUsecase: broadcastOriginalTransaction,
  );

  setUpAll(() {
    registerFallbackValue(_sender(status: PayjoinStatus.requested));
  });

  setUp(() {
    getWallet = _MockGetWalletUsecase();
    getTransactionsByTxId = _MockGetTransactionsByTxIdUsecase();
    getWalletTransaction = _MockGetWalletTransactionUsecase();
    getPayjoinById = _MockGetPayjoinByIdUsecase();
    watchPayjoin = _MockWatchPayjoinUsecase();
    watchWalletTransactionByTxId = _MockWatchWalletTransactionByTxIdUsecase();
    broadcastOriginalTransaction = _MockBroadcastOriginalTransactionUsecase();

    when(
      () => getWallet.execute(any(), sync: any(named: 'sync')),
    ).thenAnswer((_) async => _testWallet());
    // By default the forced sync'd lookup finds nothing — individual tests
    // override it to simulate the broadcast becoming visible on demand. The
    // usecase returns a Result now, so the "nothing" case is Ok(null).
    when(
      () => getWalletTransaction.execute(
        txId: any(named: 'txId'),
        walletId: any(named: 'walletId'),
        sync: any(named: 'sync'),
      ),
    ).thenAnswer(
      (_) async =>
          const Ok<WalletTransaction?, WalletTransactionLookupFailure>(null),
    );
    when(
      () => watchPayjoin.execute(ids: any(named: 'ids')),
    ).thenAnswer((_) => const Stream.empty());
    // _loadDetailsByPayjoinId always arms a watcher for both payjoin.txId
    // (when set) and payjoin.originalTxId (always set on our fixtures) —
    // an unstubbed call here throws synchronously (mocktail returns null,
    // and .listen() on null throws), silently short-circuiting
    // _loadDetailsByPayjoinId's try/catch before state.transaction is ever
    // populated, which would make every guard test a false positive (the
    // guard never actually runs because state.payjoin stayed null).
    when(
      () => watchWalletTransactionByTxId.execute(
        txId: any(named: 'txId'),
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) => const Stream.empty());
  });

  group('TransactionDetailsCubit.broadcastPayjoinOriginalTx guard', () {
    test(
      'does NOT broadcast once the session already completed via a real '
      'payjoin: re-broadcasting the lower-fee original would race an '
      'already-broadcast payjoin transaction spending the same inputs',
      () async {
        final payjoin = _sender(
          status: PayjoinStatus.completed,
          txId: 'real-payjoin-txid',
          proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
        );
        when(
          () => getPayjoinById.execute(payjoin.uri),
        ).thenAnswer((_) async => payjoin);

        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.initByPayjoinId(payjoin.uri);

        await cubit.broadcastPayjoinOriginalTx();

        verifyNever(() => broadcastOriginalTransaction.execute(any()));
        expect(cubit.state.isBroadcastingPayjoinOriginalTx, isFalse);
      },
    );

    test('does NOT broadcast once already completed via the plain-'
        'broadcast fallback (PayjoinStatus.aborted — same isCompleted as a '
        'real payjoin, nothing left to do)', () async {
      final payjoin = _sender(status: PayjoinStatus.aborted);
      when(
        () => getPayjoinById.execute(payjoin.uri),
      ).thenAnswer((_) async => payjoin);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByPayjoinId(payjoin.uri);

      await cubit.broadcastPayjoinOriginalTx();

      verifyNever(() => broadcastOriginalTransaction.execute(any()));
    });

    test('does NOT broadcast while a proposal is still being actively '
        'processed (received, not yet completed or expired)', () async {
      final payjoin = _sender(
        status: PayjoinStatus.proposed,
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
      );
      when(
        () => getPayjoinById.execute(payjoin.uri),
      ).thenAnswer((_) async => payjoin);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByPayjoinId(payjoin.uri);

      await cubit.broadcastPayjoinOriginalTx();

      verifyNever(() => broadcastOriginalTransaction.execute(any()));
    });

    test('broadcasts while waiting for a proposal (the legitimate manual '
        'fallback)', () async {
      final payjoin = _sender(status: PayjoinStatus.requested);
      when(
        () => getPayjoinById.execute(payjoin.uri),
      ).thenAnswer((_) async => payjoin);
      final completed = _sender(status: PayjoinStatus.aborted);
      when(
        () => broadcastOriginalTransaction.execute(any()),
      ).thenAnswer((_) async => completed);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByPayjoinId(payjoin.uri);

      await cubit.broadcastPayjoinOriginalTx();

      verify(() => broadcastOriginalTransaction.execute(payjoin)).called(1);
      expect(cubit.state.payjoin, completed);
    });

    test('allows a manual retry once the repository\'s own internal '
        'fallback also gave up (expired, proposalPsbt still set)', () async {
      final payjoin = _sender(
        status: PayjoinStatus.expired,
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
      );
      when(
        () => getPayjoinById.execute(payjoin.uri),
      ).thenAnswer((_) async => payjoin);
      final completed = _sender(status: PayjoinStatus.aborted);
      when(
        () => broadcastOriginalTransaction.execute(any()),
      ).thenAnswer((_) async => completed);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByPayjoinId(payjoin.uri);

      await cubit.broadcastPayjoinOriginalTx();

      verify(() => broadcastOriginalTransaction.execute(payjoin)).called(1);
    });
  });

  group('TransactionDetailsCubit.initByPayjoinId broadcast resolution', () {
    test(
      'resolves straight to the wallet transaction when the broadcast is '
      'already visible locally — the screen must show the pending bitcoin '
      'transaction, not payjoin-session-only data (observed live: a '
      'fallback-completed send showing a stale "requested" session)',
      () async {
        // Session row still lagging on requested, but the ORIGINAL
        // transaction (the fallback broadcast) is already in the wallet.
        final payjoin = _sender(status: PayjoinStatus.requested);
        when(
          () => getPayjoinById.execute(payjoin.uri),
        ).thenAnswer((_) async => payjoin);
        when(
          () => getTransactionsByTxId.execute('sender-orig-txid'),
        ).thenAnswer(
          (_) async => [
            Transaction(
              walletTransaction: _walletTx(txId: 'sender-orig-txid'),
              payjoin: payjoin,
            ),
          ],
        );

        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.initByPayjoinId(payjoin.uri);

        expect(cubit.state.transaction?.walletTransaction, isNotNull);
        expect(
          cubit.state.transaction?.walletTransaction?.txId,
          'sender-orig-txid',
        );
        // And the displayed payjoin status derives "aborted" (fallback)
        // from the original transaction being the one on-chain, despite
        // the stale session row.
        expect(
          cubit.state.transaction?.displayPayjoinStatus,
          PayjoinStatus.aborted,
        );
      },
    );

    test('prefers the payjoin transaction over the original when the session '
        'completed for real', () async {
      final payjoin = _sender(
        status: PayjoinStatus.completed,
        txId: 'real-payjoin-txid',
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
      );
      when(
        () => getPayjoinById.execute(payjoin.uri),
      ).thenAnswer((_) async => payjoin);
      when(() => getTransactionsByTxId.execute('real-payjoin-txid')).thenAnswer(
        (_) async => [
          Transaction(
            walletTransaction: _walletTx(txId: 'real-payjoin-txid'),
            payjoin: payjoin,
          ),
        ],
      );

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByPayjoinId(payjoin.uri);

      expect(
        cubit.state.transaction?.walletTransaction?.txId,
        'real-payjoin-txid',
      );
      expect(
        cubit.state.transaction?.displayPayjoinStatus,
        PayjoinStatus.completed,
      );
    });

    test('stays on payjoin-session data while nothing is broadcast, without '
        'firing a targeted sync for a still-ongoing session', () async {
      final payjoin = _sender(status: PayjoinStatus.requested);
      when(
        () => getPayjoinById.execute(payjoin.uri),
      ).thenAnswer((_) async => payjoin);
      // Nothing visible in any wallet for either txid.
      when(
        () => getTransactionsByTxId.execute(any()),
      ).thenAnswer((_) async => [Transaction(payjoin: payjoin)]);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByPayjoinId(payjoin.uri);

      expect(cubit.state.transaction?.walletTransaction, isNull);
      expect(cubit.state.payjoin, payjoin);
      verifyNever(() => getWallet.execute(any(), sync: true));
    });

    test('waits for a forced sync\'d lookup and lands DIRECTLY on the wallet '
        'transaction when the broadcast was not visible locally yet — no '
        'payjoin-session placeholder that swaps out moments later '
        '(observed live on the receiver side of an aborted payjoin)', () async {
      final payjoin = _sender(status: PayjoinStatus.aborted);
      when(
        () => getPayjoinById.execute(payjoin.uri),
      ).thenAnswer((_) async => payjoin);

      // Invisible locally until the forced sync'd lookup pulls it in.
      var visible = false;
      when(() => getTransactionsByTxId.execute('sender-orig-txid')).thenAnswer(
        (_) async => [
          if (visible)
            Transaction(
              walletTransaction: _walletTx(txId: 'sender-orig-txid'),
              payjoin: payjoin,
            )
          else
            Transaction(payjoin: payjoin),
        ],
      );
      when(
        () => getWalletTransaction.execute(
          txId: 'sender-orig-txid',
          walletId: 'w1',
          sync: true,
        ),
      ).thenAnswer((_) async {
        visible = true;
        return Ok<WalletTransaction?, WalletTransactionLookupFailure>(
          _walletTx(txId: 'sender-orig-txid'),
        );
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByPayjoinId(payjoin.uri);

      expect(
        cubit.state.transaction?.walletTransaction?.txId,
        'sender-orig-txid',
      );
      expect(
        cubit.state.transaction?.displayPayjoinStatus,
        PayjoinStatus.aborted,
      );
    });

    test(
      'does not force a sync\'d lookup for a still-ongoing session',
      () async {
        final payjoin = _sender(status: PayjoinStatus.requested);
        when(
          () => getPayjoinById.execute(payjoin.uri),
        ).thenAnswer((_) async => payjoin);
        when(
          () => getTransactionsByTxId.execute(any()),
        ).thenAnswer((_) async => [Transaction(payjoin: payjoin)]);

        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.initByPayjoinId(payjoin.uri);

        verifyNever(
          () => getWalletTransaction.execute(
            txId: any(named: 'txId'),
            walletId: any(named: 'walletId'),
            sync: any(named: 'sync'),
          ),
        );
      },
    );

    test('fires a targeted wallet sync when the session is resolved but its '
        'broadcast transaction is not visible locally yet', () async {
      final payjoin = _sender(status: PayjoinStatus.aborted);
      when(
        () => getPayjoinById.execute(payjoin.uri),
      ).thenAnswer((_) async => payjoin);
      when(
        () => getTransactionsByTxId.execute(any()),
      ).thenAnswer((_) async => [Transaction(payjoin: payjoin)]);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByPayjoinId(payjoin.uri);
      await pumpEventQueue();

      expect(cubit.state.transaction?.walletTransaction, isNull);
      verify(() => getWallet.execute('w1', sync: true)).called(1);
    });
  });

  group('TransactionDetailsCubit payjoin reactivity on the by-tx-id path', () {
    test(
      'a payjoin event reloads the details immediately — the manual-broadcast '
      'guard flips the moment the repository resolves the session, without '
      'waiting for a wallet sync (observed live: a stale "Send without '
      'payjoin" button lingering after the fallback had already broadcast)',
      () async {
        final ongoing = _sender(status: PayjoinStatus.requested);
        final completedViaFallback = _sender(status: PayjoinStatus.aborted);
        final payjoinEvents = StreamController<Payjoin>.broadcast();
        addTearDown(payjoinEvents.close);

        var loadCount = 0;
        when(() => getTransactionsByTxId.execute(any())).thenAnswer(
          (_) async => [
            Transaction(
              payjoin: loadCount++ == 0 ? ongoing : completedViaFallback,
            ),
          ],
        );
        when(
          () => watchPayjoin.execute(ids: [ongoing.id]),
        ).thenAnswer((_) => payjoinEvents.stream);

        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.initByWalletTxId('sender-orig-txid', walletId: 'w1');

        expect(cubit.state.payjoin?.canManuallyBroadcastOriginal, isTrue);

        payjoinEvents.add(completedViaFallback);
        await pumpEventQueue();

        // Work-tree divergence from payjoin-hardening: a fallback completion
        // is an explicit `aborted` status here (not `isCompleted`), per the
        // Payjoin entity's status semantics. Either way it is terminal, and
        // the manual-broadcast guard flips shut.
        expect(cubit.state.payjoin?.isAborted, isTrue);
        expect(cubit.state.payjoin?.isOngoing, isFalse);
        expect(cubit.state.payjoin?.canManuallyBroadcastOriginal, isFalse);
      },
    );

    test('a TERMINAL payjoin event with no wallet transaction on screen yet '
        'fires a targeted sync of the wallet, so the broadcast transaction '
        'shows up promptly instead of at the next scheduled sync', () async {
      final ongoing = _sender(status: PayjoinStatus.requested);
      final completedViaFallback = _sender(status: PayjoinStatus.aborted);
      final payjoinEvents = StreamController<Payjoin>.broadcast();
      addTearDown(payjoinEvents.close);

      var loadCount = 0;
      when(() => getTransactionsByTxId.execute(any())).thenAnswer(
        (_) async => [
          Transaction(
            payjoin: loadCount++ == 0 ? ongoing : completedViaFallback,
          ),
        ],
      );
      when(
        () => watchPayjoin.execute(ids: [ongoing.id]),
      ).thenAnswer((_) => payjoinEvents.stream);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByWalletTxId('sender-orig-txid', walletId: 'w1');

      payjoinEvents.add(completedViaFallback);
      await pumpEventQueue();

      verify(() => getWallet.execute('w1', sync: true)).called(1);
    });

    test(
      'a NON-terminal payjoin event does not fire the targeted sync',
      () async {
        final ongoing = _sender(status: PayjoinStatus.requested);
        final proposed = _sender(
          status: PayjoinStatus.proposed,
          proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
        );
        final payjoinEvents = StreamController<Payjoin>.broadcast();
        addTearDown(payjoinEvents.close);

        var loadCount = 0;
        when(() => getTransactionsByTxId.execute(any())).thenAnswer(
          (_) async => [
            Transaction(payjoin: loadCount++ == 0 ? ongoing : proposed),
          ],
        );
        when(
          () => watchPayjoin.execute(ids: [ongoing.id]),
        ).thenAnswer((_) => payjoinEvents.stream);

        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.initByWalletTxId('sender-orig-txid', walletId: 'w1');

        payjoinEvents.add(proposed);
        await pumpEventQueue();

        expect(cubit.state.payjoin?.status, PayjoinStatus.proposed);
        verifyNever(() => getWallet.execute(any(), sync: true));
      },
    );
  });
}
