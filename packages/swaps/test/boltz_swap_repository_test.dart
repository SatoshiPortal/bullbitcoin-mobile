import 'package:bull_sdk/boltz.dart' as frb;
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Err, Ok;
import 'package:swaps/src/data/boltz_api.dart';
import 'package:swaps/src/data/models/swap_master_key_model.dart';
import 'package:swaps/src/data/boltz_swap_repository.dart';
import 'package:swaps/src/domain/boltz_swaps.dart';
import 'package:swaps/src/domain/entities/derived_swap_master_key.dart';
import 'package:swaps/src/domain/entities/restored_swap.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/data/models/swap_model.dart';
import 'package:swaps/src/data/swap_storage.dart';
import 'package:swaps/src/domain/entities/swap_tx_outspend.dart';
import 'package:swaps/src/data/models/swap_tx_outspend_model.dart';
import 'package:swaps/src/util.dart';
import 'package:test/test.dart';

class _MockBoltzDatasource extends Mock implements BoltzDatasource {}

class _MockSwapStorage extends Mock implements SwapStorage {}

class _PassthroughElectrum implements ElectrumRunner {
  final bool custom;

  _PassthroughElectrum({this.custom = false});

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

  @override
  Future<bool> usesCustomServers({
    required bool isLiquid,
    required bool isTestnet,
  }) async => custom;
}

class _FakeLockupChain implements LockupChain {
  String? txid = 'computed-txid';
  bool known = false;

  @override
  Future<String?> txidOf({
    required String signedTx,
    required bool isLiquid,
  }) async => txid;

  LockupBroadcast outcome = const LockupOutcomeUnknown();
  final broadcasts = <String>[];

  @override
  Future<bool> isKnown({
    required String txid,
    required String signedTx,
    required bool isLiquid,
    required bool isTestnet,
  }) async => known;

  @override
  Future<LockupBroadcast> broadcast({
    required String signedTx,
    required bool isLiquid,
    required bool isTestnet,
  }) async {
    broadcasts.add(signedTx);
    return outcome;
  }
}

void main() {
  late _MockBoltzDatasource boltz;
  late _FakeLockupChain lockupChain;
  final stores = <SwapModel>[];
  late _MockSwapStorage storage;
  final walletTxs = <String, SwapWalletTx>{};

  SwapModel chainModel({
    String status = 'refundable',
    String? receiveTxid,
    String? refundTxid,
    String? sendTxid = 'lockup-txid',
    String? refundAddress = 'lq1refund',
    int? claimFees,
    String? pendingLockupTx,
    String? pendingLockupTxid,
    SwapType type = SwapType.liquidToBitcoin,
  }) => SwapModel.chain(
    id: 'D5gdAL9UI29W',
    type: type.name,
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
    claimFees: claimFees,
    pendingLockupTx: pendingLockupTx,
    pendingLockupTxid: pendingLockupTxid,
  );

  BoltzSwapRepository repo({
    int fastest = 50,
    bool customElectrum = false,
    List<SwapWalletInfo> wallets = const [],
  }) => BoltzSwapRepository(
    boltz: boltz,
    isTestnet: false,
    electrum: _PassthroughElectrum(custom: customElectrum),
    lockupChain: lockupChain,
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
    wallets: ({required bool isTestnet}) async => wallets,
    swapMasterKeySource: ({required bool isTestnet}) async =>
        const DerivedSwapMasterKey(
          walletFingerprint: 'f00dbabe',
          xprv: 'xprv',
          xpub: 'xpub',
          mnemonic: 'ab cd',
          fingerprint: 'cafe0001',
          isTestnet: false,
        ),
  );

  Swap chainSwap({
    String status = 'refundable',
    String? receiveTxid,
    String? refundTxid,
    String? sendTxid = 'lockup-txid',
    String? refundAddress = 'lq1refund',
    int? claimFees,
  }) => chainModel(
    status: status,
    receiveTxid: receiveTxid,
    refundTxid: refundTxid,
    sendTxid: sendTxid,
    refundAddress: refundAddress,
    claimFees: claimFees,
  ).toEntity();

  setUp(() {
    boltz = _MockBoltzDatasource();
    lockupChain = _FakeLockupChain();
    storage = _MockSwapStorage();
    walletTxs.clear();
    when(() => boltz.storage).thenReturn(storage);
    when(() => storage.fetch(any())).thenAnswer((_) async => chainModel());
    stores.clear();
    when(() => storage.store(any())).thenAnswer((inv) async {
      stores.add(inv.positionalArguments.first as SwapModel);
    });
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

  group('rescue', () {
    final claimToLiquid = RestoredSwap(
      id: 'restored-1',
      kind: RestoredSwapKind.crossChain,
      status: SwapStatus.pending,
      recoverable: true,
      amountSat: 100000,
      createdAt: DateTime(2026, 7),
      fromAsset: 'BTC',
      toAsset: 'L-BTC',
    );
    const wallets = [
      SwapWalletInfo(id: 'w-btc', isLiquid: false, isDefault: true),
      SwapWalletInfo(id: 'w-liquid', isLiquid: true, isDefault: true),
    ];

    test('refuses a wallet on the other side of the swap', () async {
      final result = await repo(
        wallets: wallets,
      ).rescue(claimToLiquid, walletId: 'w-btc');

      expect(result, isA<Err<Swap, SwapsFailure>>());
      verifyNever(() => storage.store(any()));
    });

    test('refuses a wallet it does not know', () async {
      final result = await repo(
        wallets: wallets,
      ).rescue(claimToLiquid, walletId: 'w-gone');

      expect(result, isA<Err<Swap, SwapsFailure>>());
      verifyNever(() => storage.store(any()));
    });
  });

  group('pending lockup', () {
    SwapModel pending({
      String status = 'pending',
      String? txid = 'pend-txid',
      SwapType type = SwapType.bitcoinToLiquid,
    }) => chainModel(
      status: status,
      sendTxid: null,
      pendingLockupTx: 'signed-pset',
      pendingLockupTxid: txid,
      type: type,
    );

    ChainSwapModel stored() => stores.last as ChainSwapModel;

    Future<void> resolve(SwapModel model) async {
      when(() => storage.fetch(any())).thenAnswer((_) async => model);
      await repo().resolvePendingLockup(model.toEntity());
    }

    test('a txid our servers know is recorded without a rebroadcast', () async {
      lockupChain.known = true;

      await resolve(pending());

      expect(stored().sendTxid, 'pend-txid');
      expect(stored().pendingLockupTx, isNull);
      expect(lockupChain.broadcasts, isEmpty);
    });

    test(
      'a failed swap is never funded fresh when the lockup never went out',
      () async {
        lockupChain.known = false;

        await resolve(pending(status: 'expired'));

        expect(stored().sendTxid, isNull);
        expect(stored().pendingLockupTx, isNull);
        expect(lockupChain.broadcasts, isEmpty);
      },
    );

    test(
      'an unseen lockup is rebroadcast as the identical transaction',
      () async {
        lockupChain
          ..known = false
          ..outcome = const LockupAccepted('pend-txid');

        await resolve(pending());

        expect(lockupChain.broadcasts, ['signed-pset']);
        expect(stored().sendTxid, 'pend-txid');
      },
    );

    test('a node rejection drops the pending lockup', () async {
      lockupChain
        ..known = false
        ..outcome = const LockupRejected();

      await resolve(pending());

      expect(stored().pendingLockupTx, isNull);
      expect(stored().sendTxid, isNull);
    });

    test('an unclear answer keeps it pending', () async {
      lockupChain.outcome = const LockupOutcomeUnknown();

      await resolve(pending());

      verifyNever(() => storage.store(any()));
    });

    test('a Liquid lockup already in chain waits for its txid', () async {
      lockupChain.outcome = const LockupAlreadyInChain();

      await resolve(pending(txid: null, type: SwapType.liquidToBitcoin));

      verifyNever(() => storage.store(any()));
    });

    test('a Liquid candidate our server confirms is recorded', () async {
      lockupChain.known = true;

      await resolve(pending(type: SwapType.liquidToBitcoin));

      expect(stored().sendTxid, 'pend-txid');
      expect(lockupChain.broadcasts, isEmpty);
    });

    test('an unconfirmed Liquid candidate is not proof of absence', () async {
      lockupChain
        ..known = false
        ..outcome = const LockupOutcomeUnknown();

      await resolve(pending(status: 'expired', type: SwapType.liquidToBitcoin));

      expect(lockupChain.broadcasts, ['signed-pset']);
      verifyNever(() => storage.store(any()));
    });

    test('a swap that records a lockup refuses another', () async {
      when(() => storage.fetch(any())).thenAnswer((_) async => chainModel());

      final result = await repo().recordPendingLockup(
        swapId: 'D5gdAL9UI29W',
        signedTx: 'other',
      );

      expect(result, isA<Err<Swap, SwapsFailure>>());
      verifyNever(() => storage.store(any()));
    });

    test('a lockup being confirmed refuses a different one', () async {
      when(() => storage.fetch(any())).thenAnswer((_) async => pending());

      final result = await repo().recordPendingLockup(
        swapId: 'D5gdAL9UI29W',
        signedTx: 'other',
      );

      expect(result, isA<Err<Swap, SwapsFailure>>());
      verifyNever(() => storage.store(any()));
    });

    test('the first recorded lockup is never replaced', () async {
      await repo().markLockupBroadcast(
        swapId: 'D5gdAL9UI29W',
        txid: 'second-lockup',
      );

      expect(stored().sendTxid, 'lockup-txid');
    });
  });

  group('claim', () {
    void stubClaimBroadcast() {
      when(
        () => boltz.claimLbtcToBtcChainSwap(
          swapId: any(named: 'swapId'),
          claimBitcoinAddress: any(named: 'claimBitcoinAddress'),
          absoluteFees: any(named: 'absoluteFees'),
          tryCooperate: any(named: 'tryCooperate'),
          electrum: any(named: 'electrum'),
        ),
      ).thenAnswer((_) async => 'claim-hex');
      when(
        () => boltz.broadcastChainSwapClaim(
          swapId: any(named: 'swapId'),
          signedTxHex: any(named: 'signedTxHex'),
          broadcastViaBoltz: any(named: 'broadcastViaBoltz'),
          electrum: any(named: 'electrum'),
        ),
      ).thenAnswer((_) async => 'claim-txid');
    }

    int claimedFee() =>
        verify(
              () => boltz.claimLbtcToBtcChainSwap(
                swapId: any(named: 'swapId'),
                claimBitcoinAddress: any(named: 'claimBitcoinAddress'),
                absoluteFees: captureAny(named: 'absoluteFees'),
                tryCooperate: any(named: 'tryCooperate'),
                electrum: any(named: 'electrum'),
              ),
            ).captured.single
            as int;

    test('pays the live fee over the stored creation-time quote', () async {
      when(
        () => boltz.getChainClaimTxSize(
          swapId: any(named: 'swapId'),
          claimAddress: any(named: 'claimAddress'),
          isCooperative: any(named: 'isCooperative'),
          electrum: any(named: 'electrum'),
        ),
      ).thenAnswer((_) async => 200);
      stubClaimBroadcast();

      final txid = await repo(
        fastest: 900,
      ).claim(chainSwap(status: 'claimable', claimFees: 300));

      expect(txid, 'claim-txid');
      expect(claimedFee(), 900);
    });

    test('prices the script-path fallback on its own size', () async {
      when(
        () => boltz.getChainClaimTxSize(
          swapId: any(named: 'swapId'),
          claimAddress: any(named: 'claimAddress'),
          isCooperative: true,
          electrum: any(named: 'electrum'),
        ),
      ).thenAnswer((_) async => 200);
      when(
        () => boltz.getChainClaimTxSize(
          swapId: any(named: 'swapId'),
          claimAddress: any(named: 'claimAddress'),
          isCooperative: false,
          electrum: any(named: 'electrum'),
        ),
      ).thenAnswer((_) async => 300);
      when(
        () => boltz.claimLbtcToBtcChainSwap(
          swapId: any(named: 'swapId'),
          claimBitcoinAddress: any(named: 'claimBitcoinAddress'),
          absoluteFees: any(named: 'absoluteFees'),
          tryCooperate: true,
          electrum: any(named: 'electrum'),
        ),
      ).thenThrow(Exception('coop refused'));
      when(
        () => boltz.claimLbtcToBtcChainSwap(
          swapId: any(named: 'swapId'),
          claimBitcoinAddress: any(named: 'claimBitcoinAddress'),
          absoluteFees: any(named: 'absoluteFees'),
          tryCooperate: false,
          electrum: any(named: 'electrum'),
        ),
      ).thenAnswer((_) async => 'claim-hex');
      when(
        () => boltz.broadcastChainSwapClaim(
          swapId: any(named: 'swapId'),
          signedTxHex: any(named: 'signedTxHex'),
          broadcastViaBoltz: any(named: 'broadcastViaBoltz'),
          electrum: any(named: 'electrum'),
        ),
      ).thenAnswer((_) async => 'claim-txid');

      await repo(fastest: 1).claim(chainSwap(status: 'claimable'));

      verify(
        () => boltz.claimLbtcToBtcChainSwap(
          swapId: any(named: 'swapId'),
          claimBitcoinAddress: any(named: 'claimBitcoinAddress'),
          absoluteFees: 300,
          tryCooperate: false,
          electrum: any(named: 'electrum'),
        ),
      ).called(1);
    });

    test(
      'falls back to the stored fee when the claim cannot be sized',
      () async {
        when(
          () => boltz.getChainClaimTxSize(
            swapId: any(named: 'swapId'),
            claimAddress: any(named: 'claimAddress'),
            isCooperative: any(named: 'isCooperative'),
            electrum: any(named: 'electrum'),
          ),
        ).thenThrow(Exception('sizing failed'));
        stubClaimBroadcast();

        await repo(
          fastest: 900,
        ).claim(chainSwap(status: 'claimable', claimFees: 300));

        expect(claimedFee(), 300);
      },
    );

    test('sizes a chain claim against the user\'s electrum', () async {
      when(
        () => boltz.getChainClaimTxSize(
          swapId: any(named: 'swapId'),
          claimAddress: any(named: 'claimAddress'),
          isCooperative: any(named: 'isCooperative'),
          electrum: any(named: 'electrum'),
        ),
      ).thenAnswer((_) async => 200);
      when(
        () => boltz.claimLbtcToBtcChainSwap(
          swapId: any(named: 'swapId'),
          claimBitcoinAddress: any(named: 'claimBitcoinAddress'),
          absoluteFees: any(named: 'absoluteFees'),
          tryCooperate: any(named: 'tryCooperate'),
          electrum: any(named: 'electrum'),
        ),
      ).thenThrow(Exception('broadcast failed'));

      await expectLater(
        repo().claim(
          chainSwap(status: 'claimable', sendTxid: 'lockup-txid'),
          scriptPathOnly: true,
        ),
        throwsA(isA<SwapsException>()),
      );
      verify(
        () => boltz.getChainClaimTxSize(
          swapId: any(named: 'swapId'),
          claimAddress: any(named: 'claimAddress'),
          isCooperative: any(named: 'isCooperative'),
          electrum: _PassthroughElectrum.connection,
        ),
      ).called(1);
    });
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

    test('custom electrum never asks a third-party explorer', () async {
      when(
        () => boltz.refundLbtcToBtcChainSwap(
          swapId: any(named: 'swapId'),
          refundLiquidAddress: any(named: 'refundLiquidAddress'),
          absoluteFees: any(named: 'absoluteFees'),
          tryCooperate: any(named: 'tryCooperate'),
          electrum: any(named: 'electrum'),
        ),
      ).thenThrow(Exception('broadcast failed'));

      await expectLater(
        repo(customElectrum: true).refund(chainSwap()),
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

  group('resolveScriptPath (zero Boltz)', () {
    test('refunds a stuck swap script-path only — never requests a Boltz '
        'cooperative signature and broadcasts via electrum', () async {
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

      final result = await repo().resolveScriptPath(chainSwap());

      expect(result, isA<Ok<Swap, SwapsFailure>>());
      expect(
        stores.last.toEntity(),
        isA<ChainSwap>().having(
          (s) => s.refundTxid,
          'refundTxid',
          'refund-txid',
        ),
      );
      final tryCooperate = verify(
        () => boltz.refundLbtcToBtcChainSwap(
          swapId: any(named: 'swapId'),
          refundLiquidAddress: any(named: 'refundLiquidAddress'),
          absoluteFees: any(named: 'absoluteFees'),
          tryCooperate: captureAny(named: 'tryCooperate'),
          electrum: any(named: 'electrum'),
        ),
      ).captured;
      expect(
        tryCooperate,
        everyElement(isFalse),
        reason: 'cooperative signing would call the Boltz API',
      );
      final broadcastViaBoltz = verify(
        () => boltz.broadcastChainSwapRefund(
          swapId: any(named: 'swapId'),
          signedTxHex: any(named: 'signedTxHex'),
          broadcastViaBoltz: captureAny(named: 'broadcastViaBoltz'),
          electrum: any(named: 'electrum'),
        ),
      ).captured;
      expect(broadcastViaBoltz, everyElement(isFalse));
    });

    test('a failed script-path resolve does NOT fall back to the Boltz '
        'outspend lookup', () async {
      when(
        () => boltz.refundLbtcToBtcChainSwap(
          swapId: any(named: 'swapId'),
          refundLiquidAddress: any(named: 'refundLiquidAddress'),
          absoluteFees: any(named: 'absoluteFees'),
          tryCooperate: any(named: 'tryCooperate'),
          electrum: any(named: 'electrum'),
        ),
      ).thenThrow(Exception('broadcast failed'));

      final result = await repo().resolveScriptPath(chainSwap());

      expect(result, isA<Err<Swap, SwapsFailure>>());
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
          lockupChain: lockupChain,
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
          swapMasterKeySource: ({required bool isTestnet}) async => null,
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

    test('our lockup in flight is paid, never claimable', () async {
      for (final kind in [frb.SwapType.submarine, frb.SwapType.chain]) {
        for (final status in ['transaction.mempool', 'transaction.confirmed']) {
          stubSummaries(summary(kind: kind, status: status));

          final restored = await repo().restoreSwaps(isTestnet: false);

          expect(
            restored.single.status,
            SwapStatus.paid,
            reason: '$kind $status',
          );
        }
      }
    });

    test(
      'a reverse swap with Boltz\'s lockup in flight is claimable',
      () async {
        stubSummaries(
          summary(kind: frb.SwapType.reverse, status: 'transaction.mempool'),
        );

        final restored = await repo().restoreSwaps(isTestnet: false);

        expect(restored.single.status, SwapStatus.claimable);
      },
    );

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

    const chainWallets = [
      SwapWalletInfo(id: 'w-btc', isLiquid: false, isDefault: true),
      SwapWalletInfo(id: 'w-liquid', isLiquid: true, isDefault: true),
    ];

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
        () => boltz.swapMasterKeyReady(
          walletFingerprint: any(named: 'walletFingerprint'),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => boltz.getBtcToLbtcChainSwapLimits(),
      ).thenAnswer((_) async => (25000, 1000000));
      when(
        () => boltz.getSwapFees(SwapType.bitcoinToLiquid),
      ).thenAnswer((_) async => const SwapFees());
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
      final created = await repo(wallets: chainWallets)
          .createBitcoinToLiquidSwap(
            sendWalletId: 'w-btc',
            amountSat: 30000,
            destination: const ToWallet('w-liquid'),
          );
      expect(created, isA<Ok<ChainSwap, SwapsFailure>>());
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

  group('lightning send creation', () {
    const btcWallets = [
      SwapWalletInfo(id: 'w-btc', isLiquid: false, isDefault: true),
    ];

    SwapModel lnSend(String id, {String status = 'pending', String? type}) =>
        SwapModel.lnSend(
          id: id,
          type: type ?? SwapType.bitcoinToLightning.name,
          status: status,
          keyIndex: 0,
          creationTime: 1,
          sendWalletId: 'w-btc',
          paymentAddress: 'bc1plockup',
          paymentAmount: 51000,
          invoice: 'LNBC1INVOICE',
        );

    test('finds only the pending swap of the same direction', () async {
      when(() => storage.fetchAll(walletId: 'w-btc')).thenAnswer(
        (_) async => [
          lnSend('paidSwap0001', status: 'paid'),
          lnSend('liquidSwap01', type: SwapType.liquidToLightning.name),
          lnSend('pendingSwap1'),
        ],
      );

      final found = await repo().getSendSwapByInvoice(
        invoice: 'lnbc1invoice',
        walletId: 'w-btc',
        type: SwapType.bitcoinToLightning,
      );

      expect(found?.id, 'pendingSwap1');
    });

    test('reuses the pending swap for the same invoice', () async {
      final pending = lnSend('pendingSwap1');
      when(
        () => storage.fetchAll(walletId: 'w-btc'),
      ).thenAnswer((_) async => [pending]);
      when(
        () => boltz.reconcileSwaps(['pendingSwap1']),
      ).thenAnswer((_) async {});
      when(
        () => storage.fetch('pendingSwap1'),
      ).thenAnswer((_) async => pending);

      final created = await repo(wallets: btcWallets)
          .createBitcoinToLightningSwap(
            walletId: 'w-btc',
            invoice: 'lnbc1invoice',
          );

      expect(
        created,
        isA<Ok<LnSendSwap, SwapsFailure>>().having(
          (ok) => ok.value.id,
          'id',
          'pendingSwap1',
        ),
      );
      verify(() => boltz.reconcileSwaps(['pendingSwap1'])).called(1);
      verifyNever(() => boltz.decodeInvoice(any()));
    });

    test('refuses while the invoice\'s swap turns out funded', () async {
      when(
        () => storage.fetchAll(walletId: 'w-btc'),
      ).thenAnswer((_) async => [lnSend('pendingSwap1')]);
      when(
        () => boltz.reconcileSwaps(['pendingSwap1']),
      ).thenAnswer((_) async {});
      when(
        () => storage.fetch('pendingSwap1'),
      ).thenAnswer((_) async => lnSend('pendingSwap1', status: 'paid'));

      final created = await repo(wallets: btcWallets)
          .createBitcoinToLightningSwap(
            walletId: 'w-btc',
            invoice: 'lnbc1invoice',
          );

      expect(created, isA<Err<LnSendSwap, SwapsFailure>>());
      verifyNever(() => boltz.decodeInvoice(any()));
    });

    test('refuses an invoice outside the submarine limits', () async {
      when(
        () => storage.fetchAll(walletId: 'w-btc'),
      ).thenAnswer((_) async => []);
      when(
        () => boltz.decodeInvoice('lnbc1invoice'),
      ).thenAnswer((_) async => (2000000, false, null, null));
      when(
        () => boltz.getBtcSubmarineSwapLimits(),
      ).thenAnswer((_) async => (25000, 1000000));
      when(
        () => boltz.getSwapFees(SwapType.bitcoinToLightning),
      ).thenAnswer((_) async => const SwapFees());

      final created = await repo(wallets: btcWallets)
          .createBitcoinToLightningSwap(
            walletId: 'w-btc',
            invoice: 'lnbc1invoice',
          );

      expect(
        created,
        isA<Err<LnSendSwap, SwapsFailure>>().having(
          (err) => err.failure,
          'failure',
          isA<SwapsAmountOutOfLimitsFailure>(),
        ),
      );
    });

    test('refuses a wallet on the other chain', () async {
      final created = await repo(
        wallets: btcWallets,
      ).createLiquidToLightningSwap(walletId: 'w-btc', invoice: 'lnbc1invoice');

      expect(created, isA<Err<LnSendSwap, SwapsFailure>>());
      verifyNever(() => storage.fetchAll(walletId: any(named: 'walletId')));
    });
  });
}
