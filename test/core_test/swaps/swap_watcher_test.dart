import 'dart:async';

import 'package:bb_mobile/core/fees/data/fees_repository.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/data/services/swap_watcher.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap_tx_outspend.dart'
    hide SwapDirection;
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeBoltzSwapRepository implements BoltzSwapRepository {
  Swap swap;
  int claimCalls = 0;
  int refundCalls = 0;
  Duration claimDelay = Duration.zero;
  Object? claimError;
  String? outspendTxid;

  FakeBoltzSwapRepository(this.swap);

  @override
  Future<Swap> getSwap({required String swapId}) async => swap;

  @override
  Future<String> claimLightningToLiquidSwap({
    required String swapId,
    required String liquidAddress,
    required int absoluteFees,
    bool cooperate = true,
  }) async {
    claimCalls++;
    if (claimDelay > Duration.zero) {
      await Future.delayed(claimDelay);
    }
    final error = claimError;
    if (error != null) throw error;
    return 'claim-txid';
  }

  @override
  Future<String> refundLiquidToLightningSwap({
    required String swapId,
    required String liquidAddress,
    required int absoluteFees,
    bool cooperate = true,
  }) async {
    refundCalls++;
    final error = claimError;
    if (error != null) throw error;
    return 'refund-txid';
  }

  @override
  Future<int> getSwapClaimTxSize({
    required String swapId,
    required SwapType swapType,
    bool isCooperative = true,
    String? claimAddressForChainSwaps,
  }) async => 1000;

  @override
  Future<int> getSwapRefundTxSize({
    required String swapId,
    required SwapType swapType,
    bool isCooperative = true,
    String? refundAddressForChainSwaps,
  }) async => 1000;

  @override
  Future<Swap> updateSwapFields(
    String swapId, {
    SwapStatus? status,
    String? receiveTxid,
    String? refundTxid,
    String? receiveAddress,
    String? refundAddress,
    String? preimage,
    int? claimFee,
    int? refundFee,
    DateTime? completionTime,
  }) async {
    final current = swap;
    final fees = (current.fees ?? const SwapFees()).copyWith(
      claimFee: claimFee ?? current.fees?.claimFee,
      refundFee: refundFee ?? current.fees?.refundFee,
    );
    swap = switch (current) {
      LnReceiveSwap() => current.copyWith(
        status: status ?? current.status,
        receiveTxid: receiveTxid ?? current.receiveTxid,
        receiveAddress: receiveAddress ?? current.receiveAddress,
        completionTime: completionTime ?? current.completionTime,
        fees: fees,
      ),
      LnSendSwap() => current.copyWith(
        status: status ?? current.status,
        refundTxid: refundTxid ?? current.refundTxid,
        refundAddress: refundAddress ?? current.refundAddress,
        preimage: preimage ?? current.preimage,
        completionTime: completionTime ?? current.completionTime,
        fees: fees,
      ),
      ChainSwap() => current.copyWith(
        status: status ?? current.status,
        receiveTxid: receiveTxid ?? current.receiveTxid,
        refundTxid: refundTxid ?? current.refundTxid,
        completionTime: completionTime ?? current.completionTime,
        fees: fees,
      ),
    };
    return swap;
  }

  @override
  void unsubscribeFromSwaps(List<String> swapIds) {}

  @override
  void subscribeToSwaps(List<String> swapIds) {}

  @override
  Future<SwapTxOutspend> checkSwapLockupOutspend({
    required String swapId,
    required SwapType swapType,
    required Network network,
    dynamic swapDirection,
    bool isClaim = true,
  }) async => SwapTxOutspend(txid: outspendTxid, timestamp: null);

  @override
  Stream<Swap> get swapUpdatesStream => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class FakeFeesRepository implements FeesRepository {
  /// 0.5 sat/vb relative estimate: with a 1000 vb tx this gives 500 sats.
  @override
  Future<FeeOptions> getNetworkFees({required Network network}) async =>
      const FeeOptions(
        fastest: NetworkFee.relative(0.5),
        economic: NetworkFee.relative(0.3),
        slow: NetworkFee.relative(0.1),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class FakeWalletAddressRepository implements WalletAddressRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LnReceiveSwap claimableSwap() => Swap.lnReceive(
        id: 'rcv123456789',
        keyIndex: 0,
        type: SwapType.lightningToLiquid,
        status: SwapStatus.claimable,
        environment: Environment.mainnet,
        creationTime: DateTime(2026, 6, 12),
        receiveWalletId: 'w1',
        invoice: 'lnbc10u1invoice',
        receiveAddress: 'lq1qqaddress',
        fees: const SwapFees(claimFee: 100),
      ) as LnReceiveSwap;

  LnSendSwap refundableSwap() => Swap.lnSend(
        id: 'snd123456789',
        keyIndex: 0,
        type: SwapType.liquidToLightning,
        status: SwapStatus.refundable,
        environment: Environment.mainnet,
        creationTime: DateTime(2026, 6, 12),
        sendWalletId: 'w1',
        invoice: 'lnbc10u1invoice',
        paymentAddress: 'lq1qqlockup',
        paymentAmount: 10000,
        sendTxid: 'lockup-txid',
        refundAddress: 'lq1qqrefund',
      ) as LnSendSwap;

  SwapWatcherService watcher(FakeBoltzSwapRepository repo) =>
      SwapWatcherService(
        boltzRepo: repo,
        walletAddressRepository: FakeWalletAddressRepository(),
        feesRepository: FakeFeesRepository(),
        autoStart: false,
      );

  group('claim execution', () {
    test('claims once, persists completed status and the actual fee used',
        () async {
      final repo = FakeBoltzSwapRepository(claimableSwap());
      final service = watcher(repo);

      await service.processSwap(repo.swap);
      await Future<void>.delayed(Duration.zero);

      expect(repo.claimCalls, 1);
      expect(repo.swap.status, SwapStatus.completed);
      expect((repo.swap as LnReceiveSwap).receiveTxid, 'claim-txid');
      // 1000 vb at 0.5 sat/vb live estimate = 500 sats — NOT the stale
      // creation-time estimate of 100.
      expect(repo.swap.fees?.claimFee, 500);
    });

    test('concurrent events for the same swap broadcast exactly once',
        () async {
      final repo = FakeBoltzSwapRepository(claimableSwap())
        ..claimDelay = const Duration(milliseconds: 50);
      final service = watcher(repo);

      final first = service.processSwap(repo.swap);
      final second = service.processSwap(repo.swap);
      final third = service.processSwap(repo.swap);
      await Future.wait([first, second, third]);
      // Drain the coalesced re-run.
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(repo.claimCalls, 1);
      expect(repo.swap.status, SwapStatus.completed);
    });

    test('failed claim backs off instead of retrying on the next event',
        () async {
      final repo = FakeBoltzSwapRepository(claimableSwap())
        ..claimError = Exception('broadcast failed');
      final service = watcher(repo);

      await service.processSwap(repo.swap);
      // coop + script-path fallback both fail -> 2 attempts in one action
      expect(repo.claimCalls, 2);

      await service.processSwap(repo.swap);
      // Backoff: no new attempts on an immediately replayed event.
      expect(repo.claimCalls, 2);
      expect(repo.swap.status, SwapStatus.claimable);
    });

    test('recovers via outspend check when broadcast fails but tx exists',
        () async {
      final repo = FakeBoltzSwapRepository(claimableSwap())
        ..claimError = Exception('bad-txns-inputs-missingorspent')
        ..outspendTxid = 'already-claimed-txid';
      final service = watcher(repo);

      await service.processSwap(repo.swap);

      expect(repo.swap.status, SwapStatus.completed);
      expect((repo.swap as LnReceiveSwap).receiveTxid, 'already-claimed-txid');
    });

    test('direct (MRH) payments are never claimed', () async {
      final repo = FakeBoltzSwapRepository(
        claimableSwap().copyWith(wasDirectPayment: true),
      );
      final service = watcher(repo);

      await service.processSwap(repo.swap);

      expect(repo.claimCalls, 0);
    });
  });

  group('refund execution', () {
    test('refund persists refunded status and the refund fee', () async {
      final repo = FakeBoltzSwapRepository(refundableSwap());
      final service = watcher(repo);

      await service.processSwap(repo.swap);
      await Future<void>.delayed(Duration.zero);

      expect(repo.refundCalls, 1);
      expect(repo.swap.status, SwapStatus.refunded);
      expect((repo.swap as LnSendSwap).refundTxid, 'refund-txid');
      expect(repo.swap.fees?.refundFee, 500);
      expect(repo.swap.fees?.claimFee, isNull);
    });

    test('already refunded swap does nothing', () async {
      final repo = FakeBoltzSwapRepository(
        refundableSwap().copyWith(refundTxid: 'existing'),
      );
      final service = watcher(repo);

      await service.processSwap(repo.swap);

      expect(repo.refundCalls, 0);
    });
  });
}
