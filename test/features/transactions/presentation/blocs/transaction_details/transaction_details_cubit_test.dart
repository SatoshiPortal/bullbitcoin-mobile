import 'package:bb_mobile/core/entities/signer_entity.dart' show SignerEntity;
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/get_payjoin_by_id_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/process_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transactions_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class _MockGetTransactionsByTxIdUsecase extends Mock
    implements GetTransactionsByTxIdUsecase {}

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

class _MockProcessSwapUsecase extends Mock implements ProcessSwapUsecase {}

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
  late _MockGetPayjoinByIdUsecase getPayjoinById;
  late _MockWatchPayjoinUsecase watchPayjoin;
  late _MockWatchWalletTransactionByTxIdUsecase watchWalletTransactionByTxId;
  late _MockBroadcastOriginalTransactionUsecase broadcastOriginalTransaction;

  TransactionDetailsCubit buildCubit() => TransactionDetailsCubit(
    getWalletUsecase: getWallet,
    getTransactionsByTxIdUsecase: _MockGetTransactionsByTxIdUsecase(),
    watchWalletTransactionByTxIdUsecase: watchWalletTransactionByTxId,
    getSwapUsecase: _MockGetSwapUsecase(),
    getPayjoinByIdUsecase: getPayjoinById,
    getOrderUsecase: _MockGetOrderUsecase(),
    watchSwapUsecase: _MockWatchSwapUsecase(),
    watchPayjoinUsecase: watchPayjoin,
    labelsFacade: _MockLabelsFacade(),
    broadcastOriginalTransactionUsecase: broadcastOriginalTransaction,
    processSwapUsecase: _MockProcessSwapUsecase(),
  );

  setUpAll(() {
    registerFallbackValue(_sender(status: PayjoinStatus.requested));
  });

  setUp(() {
    getWallet = _MockGetWalletUsecase();
    getPayjoinById = _MockGetPayjoinByIdUsecase();
    watchPayjoin = _MockWatchPayjoinUsecase();
    watchWalletTransactionByTxId = _MockWatchWalletTransactionByTxIdUsecase();
    broadcastOriginalTransaction = _MockBroadcastOriginalTransactionUsecase();

    when(
      () => getWallet.execute(any(), sync: any(named: 'sync')),
    ).thenAnswer((_) async => _testWallet());
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
        'broadcast fallback (txId null survives — same as a real payjoin, '
        'nothing left to do)', () async {
      final payjoin = _sender(status: PayjoinStatus.completed);
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
      final completed = _sender(status: PayjoinStatus.completed);
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
      final completed = _sender(status: PayjoinStatus.completed);
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
}
