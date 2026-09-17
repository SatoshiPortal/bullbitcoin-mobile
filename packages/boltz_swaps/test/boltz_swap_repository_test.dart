import 'package:bull_sdk/boltz.dart' as frb;
import 'package:mocktail/mocktail.dart';
import 'package:boltz_swaps/src/data/boltz_api.dart';
import 'package:boltz_swaps/src/data/models/swap_master_key_model.dart';
import 'package:boltz_swaps/src/data/boltz_swap_repository.dart';
import 'package:boltz_swaps/src/domain/entities/swap.dart';
import 'package:boltz_swaps/src/data/models/swap_model.dart';
import 'package:boltz_swaps/src/data/swap_storage.dart';
import 'package:boltz_swaps/src/domain/entities/swap_tx_outspend.dart';
import 'package:boltz_swaps/src/data/models/swap_tx_outspend_model.dart';
import 'package:boltz_swaps/src/util.dart';
import 'package:test/test.dart';

class _MockBoltzDatasource extends Mock implements BoltzDatasource {}

class _MockSwapStorage extends Mock implements SwapStorage {}

class _PassthroughElectrum implements ElectrumRunner {
  static const connection = ElectrumConnection(
    url: 'ssl://working.electrum:50002',
    validateDomain: true,
    timeout: 10,
  );

  @override
  Future<T> run<T>({
    required bool isLiquid,
    required bool isTestnet,
    required Future<T> Function(ElectrumConnection connection) operation,
    bool Function(Object error)? isTransient,
  }) => operation(connection);
}

void main() {
  late _MockBoltzDatasource boltz;
  late _MockSwapStorage storage;
  final walletTxs = <String, SwapWalletTx>{};

  SwapModel chainModel({
    String status = 'refundable',
    String? receiveTxid,
    String? refundTxid,
    String? sendTxid = 'lockup-txid',
    String? refundAddress = 'lq1refund',
  }) => SwapModel.chain(
    id: 'D5gdAL9UI29W',
    type: SwapType.liquidToBitcoin.name,
    status: status,
    keyIndex: 0,
    creationTime: DateTime(2026, 7).millisecondsSinceEpoch,
    sendWalletId: 'w-liquid',
    receiveWalletId: 'w-btc',
    paymentAddress: 'lq1lockup',
    paymentAmount: 100000,
    sendTxid: sendTxid,
    receiveTxid: receiveTxid,
    refundTxid: refundTxid,
    refundAddress: refundAddress,
  );

  BoltzSwapRepository repo({int fastest = 50}) => BoltzSwapRepository(
    boltz: boltz,
    isTestnet: false,
    electrum: _PassthroughElectrum(),
    newAddressFor: (walletId) async => 'addr-of-$walletId',
    walletTx: (txid, {required walletId}) async => walletTxs[txid],
    walletTxs: (walletId, {bool sync = false}) async =>
        walletTxs.values.toList(),
    fastestFee:
        ({
          required int txSize,
          required bool isLiquid,
          required bool isTestnet,
        }) async => fastest,
    wallets: ({required bool isTestnet}) async => const [],
    masterSeedSource: ({required bool isTestnet}) async =>
        const SwapSeedSource(mnemonic: 'ab cd', fingerprint: 'f00dbabe'),
  );

  Swap chainSwap({
    String status = 'refundable',
    String? receiveTxid,
    String? refundTxid,
    String? sendTxid = 'lockup-txid',
    String? refundAddress = 'lq1refund',
  }) => chainModel(
    status: status,
    receiveTxid: receiveTxid,
    refundTxid: refundTxid,
    sendTxid: sendTxid,
    refundAddress: refundAddress,
  ).toEntity();

  setUp(() {
    boltz = _MockBoltzDatasource();
    storage = _MockSwapStorage();
    walletTxs.clear();
    when(() => boltz.storage).thenReturn(storage);
    when(() => storage.fetch(any())).thenAnswer((_) async => chainModel());
    when(() => storage.store(any())).thenAnswer((_) async {});
    // The per-swap write lock is a pass-through here: run the closure.
    when(() => storage.mutate<Swap>(any(), any())).thenAnswer(
      (inv) => (inv.positionalArguments[1] as Future<Swap> Function())(),
    );
    when(() => storage.mutate<void>(any(), any())).thenAnswer(
      (inv) => (inv.positionalArguments[1] as Future<void> Function())(),
    );
    when(
      () => boltz.getChainRefundTxSize(
        swapId: any(named: 'swapId'),
        refundAddress: any(named: 'refundAddress'),
        isCooperative: any(named: 'isCooperative'),
        electrum: any(named: 'electrum'),
      ),
    ).thenAnswer((_) async => 200);
    when(() => boltz.unsubscribeToSwaps(any())).thenAnswer((_) {});
    when(() => boltz.subscribeToSwaps(any())).thenAnswer((_) {});
    when(() => storage.fetchByTxId(any())).thenAnswer((_) async => null);
  });

  setUpAll(() {
    registerFallbackValue(chainModel());
    registerFallbackValue(
      const ElectrumConnection(url: 'x', validateDomain: true, timeout: 5),
    );
    registerFallbackValue(SwapType.liquidToBitcoin);
    registerFallbackValue(Network.liquidMainnet);
    registerFallbackValue(SwapDirection.liquidToBitcoin);
    Future<Swap> swapWrite() async => throw UnimplementedError();
    Future<void> voidWrite() async {}
    registerFallbackValue(swapWrite);
    registerFallbackValue(voidWrite);
  });

  group('refund', () {
    test('broadcasts and settles with fee floored and capped', () async {
      when(
        () => boltz.refundLbtcToBtcChainSwap(
          swapId: any(named: 'swapId'),
          refundLiquidAddress: any(named: 'refundLiquidAddress'),
          absoluteFees: any(named: 'absoluteFees'),
          tryCooperate: any(named: 'tryCooperate'),
          electrum: any(named: 'electrum'),
        ),
      ).thenAnswer((_) async => 'signed-hex');
      when(
        () => boltz.broadcastChainSwapRefund(
          swapId: any(named: 'swapId'),
          signedTxHex: any(named: 'signedTxHex'),
          broadcastViaBoltz: any(named: 'broadcastViaBoltz'),
          electrum: any(named: 'electrum'),
        ),
      ).thenAnswer((_) async => 'refund-txid');

      final txid = await repo().refund(chainSwap());

      expect(txid, 'refund-txid');
      final stored =
          verify(() => storage.store(captureAny())).captured.last as SwapModel;
      expect(stored.status, SwapStatus.refunded.name);
    });

    test('does NOT settle on an in-wallet but outgoing spend of the lockup '
        '(change consolidation)', () async {
      when(
        () => boltz.refundLbtcToBtcChainSwap(
          swapId: any(named: 'swapId'),
          refundLiquidAddress: any(named: 'refundLiquidAddress'),
          absoluteFees: any(named: 'absoluteFees'),
          tryCooperate: any(named: 'tryCooperate'),
          electrum: any(named: 'electrum'),
        ),
      ).thenThrow(Exception('broadcast failed'));
      when(
        () => boltz.checkLockupOutspends(
          swapId: any(named: 'swapId'),
          swapType: any(named: 'swapType'),
          network: any(named: 'network'),
          swapDirection: any(named: 'swapDirection'),
          isClaim: any(named: 'isClaim'),
        ),
      ).thenAnswer(
        (_) async => const [SwapTxOutspendModel(txid: 'change-spend')],
      );
      walletTxs['change-spend'] = const SwapWalletTx(
        txId: 'change-spend',
        isIncoming: false,
      );

      await expectLater(
        repo().refund(chainSwap()),
        throwsA(isA<SwapsException>()),
      );
      verifyNever(() => storage.store(any()));
    });

    test('non-final failure skips the outspend recovery entirely', () async {
      when(
        () => boltz.refundLbtcToBtcChainSwap(
          swapId: any(named: 'swapId'),
          refundLiquidAddress: any(named: 'refundLiquidAddress'),
          absoluteFees: any(named: 'absoluteFees'),
          tryCooperate: any(named: 'tryCooperate'),
          electrum: any(named: 'electrum'),
        ),
      ).thenThrow(Exception('non-BIP68-final'));

      await expectLater(
        repo().refund(chainSwap()),
        throwsA(isA<SwapsException>()),
      );
      verifyNever(
        () => boltz.checkLockupOutspends(
          swapId: any(named: 'swapId'),
          swapType: any(named: 'swapType'),
          network: any(named: 'network'),
          swapDirection: any(named: 'swapDirection'),
          isClaim: any(named: 'isClaim'),
        ),
      );
    });

    test('is idempotent on a recorded refund txid', () async {
      final txid = await repo().refund(chainSwap(refundTxid: 'already-done'));
      expect(txid, 'already-done');
      verifyNever(() => storage.store(any()));
    });
  });

  group('verifyCompletions', () {
    test(
      'cache-first: a claim found in the cache causes no sync and no write',
      () async {
        var syncRequested = false;
        final r = BoltzSwapRepository(
          boltz: boltz,
          isTestnet: false,
          electrum: _PassthroughElectrum(),
          newAddressFor: (w) async => 'a',
          walletTx: (t, {required walletId}) async => null,
          walletTxs: (walletId, {bool sync = false}) async {
            if (sync) syncRequested = true;
            return const [SwapWalletTx(txId: 'claim-txid', isIncoming: true)];
          },
          fastestFee:
              ({
                required int txSize,
                required bool isLiquid,
                required bool isTestnet,
              }) async => 50,
          wallets: ({required bool isTestnet}) async => const [],
          masterSeedSource: ({required bool isTestnet}) async => null,
        );
        when(
          () => storage.fetchAll(
            walletId: any(named: 'walletId'),
            isTestnet: any(named: 'isTestnet'),
          ),
        ).thenAnswer(
          (_) async => [
            chainModel(status: 'completed', receiveTxid: 'claim-txid'),
          ],
        );

        await r.verifyCompletions();

        expect(syncRequested, isFalse);
        verifyNever(() => storage.store(any()));
      },
    );

    test(
      'retracts and reopens when the claim is missing even after a sync',
      () async {
        when(
          () => storage.fetchAll(
            walletId: any(named: 'walletId'),
            isTestnet: any(named: 'isTestnet'),
          ),
        ).thenAnswer(
          (_) async => [
            chainModel(status: 'completed', receiveTxid: 'bogus-claim'),
          ],
        );
        when(() => storage.fetch(any())).thenAnswer(
          (_) async => chainModel(status: 'completed', receiveTxid: 'bogus'),
        );
        walletTxs['some-other-tx'] = const SwapWalletTx(
          txId: 'some-other-tx',
          isIncoming: true,
        );

        await repo().verifyCompletions();

        final stored =
            verify(() => storage.store(captureAny())).captured.last
                as SwapModel;
        expect(stored.status, SwapStatus.refundable.name);
      },
    );

    test('reopens completed rows with funds locked and no txids', () async {
      when(
        () => storage.fetchAll(
          walletId: any(named: 'walletId'),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer((_) async => [chainModel(status: 'completed')]);
      when(
        () => storage.fetch(any()),
      ).thenAnswer((_) async => chainModel(status: 'completed'));

      await repo().verifyCompletions();

      final stored =
          verify(() => storage.store(captureAny())).captured.last as SwapModel;
      expect(stored.status, SwapStatus.refundable.name);
    });

    test('retracts a reverse completion whose claim vanished — reopens '
        'claimable with the pinned claim fee cleared', () async {
      final reverse = SwapModel.lnReceive(
        id: 'reverse-1',
        type: SwapType.lightningToBitcoin.name,
        status: 'completed',
        keyIndex: 1,
        creationTime: DateTime(2026, 7).millisecondsSinceEpoch,
        receiveWalletId: 'w-btc',
        invoice: 'lnbc1',
        receiveTxid: 'evicted-claim',
        claimFees: 3000,
      );
      when(
        () => storage.fetchAll(
          walletId: any(named: 'walletId'),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer((_) async => [reverse]);
      when(() => storage.fetch(any())).thenAnswer((_) async => reverse);
      walletTxs['unrelated'] = const SwapWalletTx(
        txId: 'unrelated',
        isIncoming: true,
      );

      await repo().verifyCompletions();

      final stored =
          verify(() => storage.store(captureAny())).captured.last as SwapModel;
      expect(stored.status, SwapStatus.claimable.name);
      expect((stored as LnReceiveSwapModel).receiveTxid, isNull);
      expect(stored.claimFees, 0);
    });

    test('never touches an MRH direct payment', () async {
      final direct = SwapModel.lnReceive(
        id: 'mrh-1',
        type: SwapType.lightningToLiquid.name,
        status: 'completed',
        keyIndex: 2,
        creationTime: DateTime(2026, 7).millisecondsSinceEpoch,
        receiveWalletId: 'w-liquid',
        invoice: 'lnbc1',
        receiveTxid: 'direct-payment',
        wasDirectPayment: true,
      );
      when(
        () => storage.fetchAll(
          walletId: any(named: 'walletId'),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer((_) async => [direct]);

      await repo().verifyCompletions();

      verifyNever(() => storage.store(any()));
    });
  });

  group('outspend recovery evidence binding', () {
    void stubFailedRefund() {
      when(
        () => boltz.refundLbtcToBtcChainSwap(
          swapId: any(named: 'swapId'),
          refundLiquidAddress: any(named: 'refundLiquidAddress'),
          absoluteFees: any(named: 'absoluteFees'),
          tryCooperate: any(named: 'tryCooperate'),
          electrum: any(named: 'electrum'),
        ),
      ).thenThrow(Exception('broadcast failed'));
    }

    void stubOutspends(String spenderTxid) {
      when(
        () => boltz.checkLockupOutspends(
          swapId: any(named: 'swapId'),
          swapType: any(named: 'swapType'),
          network: any(named: 'network'),
          swapDirection: any(named: 'swapDirection'),
          isClaim: any(named: 'isClaim'),
        ),
      ).thenAnswer((_) async => [SwapTxOutspendModel(txid: spenderTxid)]);
    }

    test('rejects an incoming candidate already recorded on another swap '
        '(hostile-backend replay)', () async {
      stubFailedRefund();
      stubOutspends('historical-claim');
      walletTxs['historical-claim'] = const SwapWalletTx(
        txId: 'historical-claim',
        isIncoming: true,
        spendsTxIds: ['lockup-txid'],
      );
      when(() => storage.fetchByTxId('historical-claim')).thenAnswer(
        (_) async => SwapModel.chain(
          id: 'other-swap',
          type: SwapType.liquidToBitcoin.name,
          status: 'completed',
          keyIndex: 9,
          creationTime: DateTime(2026, 5).millisecondsSinceEpoch,
          sendWalletId: 'w-liquid',
          paymentAddress: 'lq1old',
          paymentAmount: 50000,
          receiveTxid: 'historical-claim',
        ),
      );

      await expectLater(
        repo().refund(chainSwap()),
        throwsA(isA<SwapsException>()),
      );
      verifyNever(() => storage.store(any()));
    });

    test(
      'rejects an incoming candidate that does not spend our lockup',
      () async {
        stubFailedRefund();
        stubOutspends('foreign-incoming');
        walletTxs['foreign-incoming'] = const SwapWalletTx(
          txId: 'foreign-incoming',
          isIncoming: true,
          spendsTxIds: ['someone-elses-tx'],
        );

        await expectLater(
          repo().refund(chainSwap()),
          throwsA(isA<SwapsException>()),
        );
        verifyNever(() => storage.store(any()));
      },
    );

    test(
      'settles on an incoming candidate that DOES spend our lockup',
      () async {
        stubFailedRefund();
        stubOutspends('true-refund');
        walletTxs['true-refund'] = const SwapWalletTx(
          txId: 'true-refund',
          isIncoming: true,
          spendsTxIds: ['lockup-txid'],
        );

        final txid = await repo().refund(chainSwap());

        expect(txid, 'true-refund');
        final stored =
            verify(() => storage.store(captureAny())).captured.last
                as SwapModel;
        expect(stored.status, SwapStatus.refunded.name);
        expect((stored as ChainSwapModel).refundTxid, 'true-refund');
      },
    );
  });

  group('restore recoverability', () {
    const masterKey = SwapMasterKeyModel(
      xprv: 'xprv',
      xpub: 'xpub',
      network: 'bitcoin',
      mnemonic: 'ab cd',
      fingerprint: 'f00dbabe',
    );

    frb.RestoredSwapSummary summary({
      frb.SwapType kind = frb.SwapType.chain,
      String status = 'transaction.refunded',
      bool recoverable = false,
      String from = 'BTC',
      String to = 'L-BTC',
    }) => frb.RestoredSwapSummary(
      id: 'rSwap1234567',
      kind: kind,
      status: status,
      createdAt: BigInt.from(1750000000),
      from: from,
      to: to,
      amount: BigInt.from(50000),
      recoverable: recoverable,
    );

    void stubSummaries(frb.RestoredSwapSummary s) {
      when(
        () => boltz.getSwapMasterKey(isTestnet: any(named: 'isTestnet')),
      ).thenAnswer((_) async => masterKey);
      when(
        () => boltz.restoreSwapSummaries(
          swapMasterKey: any(named: 'swapMasterKey'),
        ),
      ).thenAnswer((_) async => [s]);
    }

    setUpAll(() => registerFallbackValue(masterKey));

    test('trusts a positive boltz verdict', () async {
      stubSummaries(summary(recoverable: true));

      final restored = await repo().restoreSwaps(isTestnet: false);

      expect(restored.single.recoverable, isTrue);
    });

    test('a chain swap boltz marked transaction.refunded stays rescuable '
        '(boltz refunded ITS side; ours may be unspent)', () async {
      stubSummaries(summary(status: 'transaction.refunded'));

      final restored = await repo().restoreSwaps(isTestnet: false);

      expect(restored.single.recoverable, isTrue);
    });

    test(
      'a chain swap in swap.refunded is also floored to rescuable',
      () async {
        stubSummaries(summary(status: 'swap.refunded'));

        final restored = await repo().restoreSwaps(isTestnet: false);

        expect(restored.single.recoverable, isTrue);
      },
    );

    test('a claimed chain swap keeps boltz\'s negative verdict', () async {
      stubSummaries(summary(status: 'transaction.claimed'));

      final restored = await repo().restoreSwaps(isTestnet: false);

      expect(restored.single.recoverable, isFalse);
    });

    test('a refunded submarine keeps boltz\'s negative verdict '
        '(refunded means OUR lockup came back)', () async {
      stubSummaries(
        summary(
          kind: frb.SwapType.submarine,
          status: 'transaction.refunded',
          to: 'BTC',
        ),
      );

      final restored = await repo().restoreSwaps(isTestnet: false);

      expect(restored.single.recoverable, isFalse);
    });

    test('a reverse swap is never floored', () async {
      stubSummaries(
        summary(kind: frb.SwapType.reverse, status: 'invoice.settled'),
      );

      final restored = await repo().restoreSwaps(isTestnet: false);

      expect(restored.single.recoverable, isFalse);
    });

    test('a non-resolved status keeps boltz\'s negative verdict', () async {
      stubSummaries(summary(status: 'swap.created'));

      final restored = await repo().restoreSwaps(isTestnet: false);

      expect(restored.single.recoverable, isFalse);
    });
  });

  group('swap key index reservation', () {
    const masterKey = SwapMasterKeyModel(
      xprv: 'xprv',
      xpub: 'xpub',
      network: 'bitcoin',
      mnemonic: 'ab cd',
      fingerprint: 'f00dbabe',
    );

    SwapModel storedChain({required int keyIndex}) => SwapModel.chain(
      id: 'stored-$keyIndex',
      type: SwapType.bitcoinToLiquid.name,
      status: 'refundable',
      keyIndex: keyIndex,
      creationTime: DateTime(2026, 7).millisecondsSinceEpoch,
      sendWalletId: 'w-btc',
      paymentAddress: 'bc1lockup',
      paymentAmount: 100000,
    );

    void stubCreation({required int? storedCounter, required int localTop}) {
      when(
        () => boltz.getSwapMasterKey(isTestnet: any(named: 'isTestnet')),
      ).thenAnswer((_) async => masterKey);
      when(
        () => storage.getSwapKeyIndex(any()),
      ).thenAnswer((_) async => storedCounter);
      when(
        () => storage.setSwapKeyIndex(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => storage.fetchAll(
          walletId: any(named: 'walletId'),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer((_) async => [storedChain(keyIndex: localTop)]);
      when(
        () =>
            boltz.restoreSwapIndex(swapMasterKey: any(named: 'swapMasterKey')),
      ).thenAnswer((_) async => -1);
      when(
        () => boltz.createBtcToLbtcChainSwap(
          sendWalletId: any(named: 'sendWalletId'),
          index: any(named: 'index'),
          amountSat: any(named: 'amountSat'),
          isTestnet: any(named: 'isTestnet'),
          btcElectrumUrl: any(named: 'btcElectrumUrl'),
          lbtcElectrumUrl: any(named: 'lbtcElectrumUrl'),
          receiveWalletId: any(named: 'receiveWalletId'),
          externalRecipientAddress: any(named: 'externalRecipientAddress'),
        ),
      ).thenAnswer((_) async => chainModel());
    }

    Future<int> createAndCaptureIndex() async {
      await repo().createBitcoinToLiquidSwap(
        sendWalletId: 'w-btc',
        amountSat: 30000,
        btcElectrumUrl: 'btc:50001',
        lbtcElectrumUrl: 'lbtc:50001',
      );
      return verify(
            () => boltz.createBtcToLbtcChainSwap(
              sendWalletId: any(named: 'sendWalletId'),
              index: captureAny(named: 'index'),
              amountSat: any(named: 'amountSat'),
              isTestnet: any(named: 'isTestnet'),
              btcElectrumUrl: any(named: 'btcElectrumUrl'),
              lbtcElectrumUrl: any(named: 'lbtcElectrumUrl'),
              receiveWalletId: any(named: 'receiveWalletId'),
              externalRecipientAddress: any(named: 'externalRecipientAddress'),
            ),
          ).captured.single
          as int;
    }

    test('a counter lagging behind a rescued swap is bumped past it '
        '(keyIndex-reuse regression)', () async {
      // A rescue imported a chain swap at index 7 (occupying 7 and 8)
      // without advancing the counter, which still says 5.
      stubCreation(storedCounter: 5, localTop: 7);

      final index = await createAndCaptureIndex();

      expect(index, 9);
      verify(() => storage.setSwapKeyIndex('f00dbabe', 11)).called(1);
    });

    test('a counter ahead of local swaps is used as-is', () async {
      stubCreation(storedCounter: 10, localTop: 7);

      final index = await createAndCaptureIndex();

      expect(index, 10);
      verify(() => storage.setSwapKeyIndex('f00dbabe', 12)).called(1);
    });

    test('an unset counter seeds past both boltz and local swaps', () async {
      stubCreation(storedCounter: null, localTop: 7);

      final index = await createAndCaptureIndex();

      expect(index, 9);
      verify(() => storage.setSwapKeyIndex('f00dbabe', 11)).called(1);
    });
  });

  group('reconcileLockupTxid (crash-window backfill)', () {
    test(
      'returns a chain swap that already has a sendTxid untouched',
      () async {
        final swap = chainSwap(sendTxid: 'already-there');

        final result = await repo().reconcileLockupTxid(swap);

        expect(identical(result, swap), isTrue);
        verifyNever(() => storage.fetchChainSwap(any()));
      },
    );

    test(
      'fails safe (returns the swap) when the secure blob is gone',
      () async {
        final swap = chainSwap(sendTxid: null);
        when(() => storage.fetchChainSwap(any())).thenThrow(
          SwapsException('no secure-storage blob for swap ${swap.id}'),
        );

        final result = await repo().reconcileLockupTxid(swap);

        expect(result.txId, isNull);
        verifyNever(() => storage.store(any()));
      },
    );
  });
}
