import 'package:mocktail/mocktail.dart';
import 'package:swaps/src/data/boltz_api.dart';
import 'package:swaps/src/data/boltz_swap_repository.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/data/models/swap_model.dart';
import 'package:swaps/src/data/swap_storage.dart';
import 'package:swaps/src/domain/entities/swap_tx_outspend.dart';
import 'package:swaps/src/data/models/swap_tx_outspend_model.dart';
import 'package:swaps/src/util.dart';
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
  });

  setUpAll(() {
    registerFallbackValue(chainModel());
    registerFallbackValue(
      const ElectrumConnection(url: 'x', validateDomain: true, timeout: 5),
    );
    registerFallbackValue(SwapType.liquidToBitcoin);
    registerFallbackValue(Network.liquidMainnet);
    registerFallbackValue(SwapDirection.liquidToBitcoin);
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
  });
}
