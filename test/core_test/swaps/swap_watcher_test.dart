import 'dart:async';

import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
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
  int? lastRefundFees;
  int swapUpdatesReads = 0;
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
    lastRefundFees = absoluteFees;
    final error = claimError;
    if (error != null) throw error;
    return 'refund-txid';
  }

  @override
  Future<String> refundLiquidToBitcoinSwap({
    required String swapId,
    required String liquidRefundAddress,
    required int absoluteFees,
    bool cooperate = true,
  }) async {
    refundCalls++;
    lastRefundFees = absoluteFees;
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
  Stream<Swap> get swapUpdatesStream {
    swapUpdatesReads++;
    return const Stream.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class FakeFeesRepository implements FeesRepository {
  /// Rates are stored in sat/kwu (1 sat/vB = 250 sat/kwu): 0.5→125, 0.3→75,
  /// 0.1→25. The default 0.5 sat/vb gives 500 sats on a 1000 vb tx.
  final int fastestSatPerKwu;

  const FakeFeesRepository({this.fastestSatPerKwu = 125});

  @override
  Future<FeeOptions> getNetworkFees({required Network network}) async =>
      FeeOptions(
        fastest: NetworkFee.relativeSatPerKwu(fastestSatPerKwu),
        economic: const NetworkFee.relativeSatPerKwu(75),
        slow: const NetworkFee.relativeSatPerKwu(25),
        minRelay: const RelativeFee(25),
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

  LnReceiveSwap claimableSwap() =>
      Swap.lnReceive(
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
          )
          as LnReceiveSwap;

  LnSendSwap refundableSwap() =>
      Swap.lnSend(
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
          )
          as LnSendSwap;

  /// A chain swap carries its amount as a plain `paymentAmount` int, unlike
  /// the LN fixtures whose placeholder invoice parses to 0 sats. It is
  /// therefore the fixture that actually exercises the amount-based fee cap.
  ChainSwap chainRefundableSwap({int paymentAmount = 1000}) =>
      Swap.chain(
            id: 'chn123456789',
            keyIndex: 0,
            type: SwapType.liquidToBitcoin,
            status: SwapStatus.refundable,
            environment: Environment.mainnet,
            creationTime: DateTime(2026, 6, 12),
            sendWalletId: 'w1',
            paymentAddress: 'lq1qqlockup',
            paymentAmount: paymentAmount,
            sendTxid: 'lockup-txid',
            refundAddress: 'lq1qqrefund',
          )
          as ChainSwap;

  SwapWatcherService watcher(
    FakeBoltzSwapRepository repo, {
    FakeFeesRepository fees = const FakeFeesRepository(),
  }) => SwapWatcherService(
    boltzRepo: repo,
    walletAddressRepository: FakeWalletAddressRepository(),
    feesRepository: fees,
  );

  group('claim execution', () {
    test(
      'claims once, persists completed status and the actual fee used',
      () async {
        final repo = FakeBoltzSwapRepository(claimableSwap());
        final service = watcher(repo);

        await service.processSwap(repo.swap);
        await Future<void>.delayed(Duration.zero);

        expect(repo.claimCalls, 1);
        expect(repo.swap.status, SwapStatus.completed);
        expect((repo.swap as LnReceiveSwap).receiveTxid, 'claim-txid');
        // The claim is pinned to the stored creation-time claimFee (100) so the
        // user receives exactly what the receive screen promised — NOT the live
        // estimate of 500 (1000 vb at 0.5 sat/vb).
        expect(repo.swap.fees?.claimFee, 100);
      },
    );

    test(
      'falls back to live fee estimation when no claimFee is stored',
      () async {
        final repo = FakeBoltzSwapRepository(
          claimableSwap().copyWith(fees: null),
        );
        final service = watcher(repo);

        await service.processSwap(repo.swap);
        await Future<void>.delayed(Duration.zero);

        expect(repo.claimCalls, 1);
        expect(repo.swap.status, SwapStatus.completed);
        // 1000 vb at 0.5 sat/vb live estimate = 500 sats.
        expect(repo.swap.fees?.claimFee, 500);
      },
    );

    test(
      'concurrent events for the same swap broadcast exactly once',
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
      },
    );

    test(
      'failed claim backs off instead of retrying on the next event',
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
      },
    );

    test(
      'recovers via outspend check when broadcast fails but tx exists',
      () async {
        final repo = FakeBoltzSwapRepository(claimableSwap())
          ..claimError = Exception('bad-txns-inputs-missingorspent')
          ..outspendTxid = 'already-claimed-txid';
        final service = watcher(repo);

        await service.processSwap(repo.swap);

        expect(repo.swap.status, SwapStatus.completed);
        expect(
          (repo.swap as LnReceiveSwap).receiveTxid,
          'already-claimed-txid',
        );
      },
    );

    test('direct (MRH) payments are never claimed', () async {
      final repo = FakeBoltzSwapRepository(
        claimableSwap().copyWith(wasDirectPayment: true),
      );
      final service = watcher(repo);

      await service.processSwap(repo.swap);

      expect(repo.claimCalls, 0);
    });
  });

  test('does not start watching when constructed', () async {
    final repo = FakeBoltzSwapRepository(claimableSwap());

    watcher(repo);
    await Future<void>.delayed(Duration.zero);

    expect(repo.swapUpdatesReads, 0);
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

  group('refund fee cap', () {
    test(
      'never burns more than half the swap when the fee API spikes',
      () async {
        final repo = FakeBoltzSwapRepository(
          chainRefundableSwap(paymentAmount: 1000),
        );
        // 10 sat/vb (2500 sat/kwu) on a 1000 vb tx would cost 10000 sats,
        // ten times the amount being refunded.
        final service = watcher(
          repo,
          fees: const FakeFeesRepository(fastestSatPerKwu: 2500),
        );

        await service.processSwap(repo.swap);
        await Future<void>.delayed(Duration.zero);

        expect(repo.refundCalls, 1);
        expect(repo.lastRefundFees, 500);
      },
    );

    test('the relay floor still wins over the cap on a dust swap', () async {
      // Half of 100 sats is 50, below the 111 sat Liquid relay floor for a
      // 1000 vb tx. Paying the floor beats broadcasting an unrelayable tx.
      final repo = FakeBoltzSwapRepository(
        chainRefundableSwap(paymentAmount: 100),
      );
      final service = watcher(repo);

      await service.processSwap(repo.swap);
      await Future<void>.delayed(Duration.zero);

      expect(repo.lastRefundFees, 111);
    });

    test('leaves a normal refund untouched', () async {
      final repo = FakeBoltzSwapRepository(
        chainRefundableSwap(paymentAmount: 100000),
      );
      final service = watcher(repo);

      await service.processSwap(repo.swap);
      await Future<void>.delayed(Duration.zero);

      // 1000 vb at 0.5 sat/vb = 500 sats, far below half the swap.
      expect(repo.lastRefundFees, 500);
    });
  });
}
