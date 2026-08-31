import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/swap/providers/boltz_engine_adapter.dart';
import 'package:bull_swap/bull_swap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockBoltzRepo extends Mock implements BoltzSwapRepository {}

class _MockGetReceiveAddress extends Mock implements GetReceiveAddressUsecase {}

LnReceiveSwap _lnReceive({required SwapType type, SwapFees? fees}) =>
    Swap.lnReceive(
          id: 'swap-1',
          keyIndex: 0,
          type: type,
          status: SwapStatus.claimable,
          environment: Environment.mainnet,
          creationTime: DateTime.utc(2026),
          receiveWalletId: 'wallet-1',
          invoice: 'invoice',
          receiveAddress: 'claim-address',
          fees: fees,
        )
        as LnReceiveSwap;

LnSendSwap _lnSend({required SwapType type, required int paymentAmount}) =>
    Swap.lnSend(
          id: 'swap-1',
          keyIndex: 0,
          type: type,
          status: SwapStatus.refundable,
          environment: Environment.mainnet,
          creationTime: DateTime.utc(2026),
          sendWalletId: 'wallet-1',
          invoice: 'invoice',
          paymentAddress: 'payment-address',
          paymentAmount: paymentAmount,
          refundAddress: 'refund-address',
        )
        as LnSendSwap;

void main() {
  late _MockBoltzRepo repo;
  late _MockGetReceiveAddress getReceiveAddress;

  BoltzEngineAdapter build({double feeRate = 2}) => BoltzEngineAdapter(
    repo,
    (network, environment) async => 'electrum',
    (network, environment) async => feeRate,
    getReceiveAddress,
  );

  setUp(() {
    repo = _MockBoltzRepo();
    getReceiveAddress = _MockGetReceiveAddress();
  });

  test(
    'claim uses a fresh live fee, not the stored creation-time fee',
    () async {
      final swap = _lnReceive(
        type: SwapType.lightningToBitcoin,
        fees: const SwapFees(claimFee: 9999),
      );
      when(() => repo.getSwap(swapId: 'swap-1')).thenAnswer((_) async => swap);
      when(
        () => repo.getSwapClaimTxSize(
          swapId: 'swap-1',
          swapType: SwapType.lightningToBitcoin,
          isCooperative: true,
          claimAddressForChainSwaps: null,
        ),
      ).thenAnswer((_) async => 200);
      when(
        () => repo.claimLightningToBitcoinSwap(
          swapId: 'swap-1',
          bitcoinAddress: 'claim-address',
          absoluteFees: 400,
          cooperate: true,
        ),
      ).thenAnswer((_) async => 'claim-txid');

      final result = await build().claim(
        'swap-1',
        environment: SwapEnvironment.mainnet,
      );

      expect(result, isA<Ok<String, SwapFailure>>());
      // 200 vbytes * 2 sat/vb = 400 (live), not the stored 9999.
      verify(
        () => repo.claimLightningToBitcoinSwap(
          swapId: 'swap-1',
          bitcoinAddress: 'claim-address',
          absoluteFees: 400,
          cooperate: true,
        ),
      ).called(1);
    },
  );

  test(
    'claim falls back to the stored fee only when live sizing fails',
    () async {
      final swap = _lnReceive(
        type: SwapType.lightningToBitcoin,
        fees: const SwapFees(claimFee: 9999),
      );
      when(() => repo.getSwap(swapId: 'swap-1')).thenAnswer((_) async => swap);
      when(
        () => repo.getSwapClaimTxSize(
          swapId: 'swap-1',
          swapType: SwapType.lightningToBitcoin,
          isCooperative: true,
          claimAddressForChainSwaps: null,
        ),
      ).thenThrow(Exception('cannot size'));
      when(
        () => repo.claimLightningToBitcoinSwap(
          swapId: 'swap-1',
          bitcoinAddress: 'claim-address',
          absoluteFees: 9999,
          cooperate: true,
        ),
      ).thenAnswer((_) async => 'claim-txid');

      final result = await build().claim(
        'swap-1',
        environment: SwapEnvironment.mainnet,
      );

      expect(result, isA<Ok<String, SwapFailure>>());
      verify(
        () => repo.claimLightningToBitcoinSwap(
          swapId: 'swap-1',
          bitcoinAddress: 'claim-address',
          absoluteFees: 9999,
          cooperate: true,
        ),
      ).called(1);
    },
  );

  test(
    'claim recomputes the larger script-path size and fee on coop failure',
    () async {
      final swap = _lnReceive(type: SwapType.lightningToBitcoin);
      when(() => repo.getSwap(swapId: 'swap-1')).thenAnswer((_) async => swap);
      when(
        () => repo.getSwapClaimTxSize(
          swapId: 'swap-1',
          swapType: SwapType.lightningToBitcoin,
          isCooperative: true,
          claimAddressForChainSwaps: null,
        ),
      ).thenAnswer((_) async => 200);
      when(
        () => repo.getSwapClaimTxSize(
          swapId: 'swap-1',
          swapType: SwapType.lightningToBitcoin,
          isCooperative: false,
          claimAddressForChainSwaps: null,
        ),
      ).thenAnswer((_) async => 300);
      when(
        () => repo.claimLightningToBitcoinSwap(
          swapId: 'swap-1',
          bitcoinAddress: 'claim-address',
          absoluteFees: 400,
          cooperate: true,
        ),
      ).thenThrow(Exception('coop refused'));
      when(
        () => repo.claimLightningToBitcoinSwap(
          swapId: 'swap-1',
          bitcoinAddress: 'claim-address',
          absoluteFees: 600,
          cooperate: false,
        ),
      ).thenAnswer((_) async => 'claim-txid');

      final result = await build().claim(
        'swap-1',
        environment: SwapEnvironment.mainnet,
      );

      expect(result, isA<Ok<String, SwapFailure>>());
      // Script path re-sizes (300 vbytes) and re-caps the fee (300*2=600),
      // never reusing the cooperative 400.
      verify(
        () => repo.claimLightningToBitcoinSwap(
          swapId: 'swap-1',
          bitcoinAddress: 'claim-address',
          absoluteFees: 600,
          cooperate: false,
        ),
      ).called(1);
    },
  );

  test('refund caps the fee at half the amount at stake', () async {
    final swap = _lnSend(type: SwapType.liquidToLightning, paymentAmount: 1000);
    when(() => repo.getSwap(swapId: 'swap-1')).thenAnswer((_) async => swap);
    when(
      () => repo.getSwapRefundTxSize(
        swapId: 'swap-1',
        swapType: SwapType.liquidToLightning,
        isCooperative: true,
        refundAddressForChainSwaps: null,
      ),
    ).thenAnswer((_) async => 100);
    when(
      () => repo.refundLiquidToLightningSwap(
        swapId: 'swap-1',
        liquidAddress: 'refund-address',
        absoluteFees: 500,
        cooperate: true,
      ),
    ).thenAnswer((_) async => 'refund-txid');

    // 100 vbytes * 50 sat/vb = 5000, but capped to half of 1000 = 500.
    final result = await build(
      feeRate: 50,
    ).refund('swap-1', environment: SwapEnvironment.mainnet);

    expect(result, isA<Ok<String, SwapFailure>>());
    verify(
      () => repo.refundLiquidToLightningSwap(
        swapId: 'swap-1',
        liquidAddress: 'refund-address',
        absoluteFees: 500,
        cooperate: true,
      ),
    ).called(1);
  });

  test('claim floors a below-relay liquid fee at the relay minimum', () async {
    final swap = _lnReceive(type: SwapType.lightningToLiquid);
    when(() => repo.getSwap(swapId: 'swap-1')).thenAnswer((_) async => swap);
    when(
      () => repo.getSwapClaimTxSize(
        swapId: 'swap-1',
        swapType: SwapType.lightningToLiquid,
        isCooperative: true,
        claimAddressForChainSwaps: null,
      ),
    ).thenAnswer((_) async => 100);
    when(
      () => repo.claimLightningToLiquidSwap(
        swapId: 'swap-1',
        liquidAddress: 'claim-address',
        absoluteFees: 12,
        cooperate: true,
      ),
    ).thenAnswer((_) async => 'claim-txid');

    // 100 * 0.01 = 1, floored to (100*0.11).ceil()+1 = 12.
    final result = await build(
      feeRate: 0.01,
    ).claim('swap-1', environment: SwapEnvironment.mainnet);

    expect(result, isA<Ok<String, SwapFailure>>());
    verify(
      () => repo.claimLightningToLiquidSwap(
        swapId: 'swap-1',
        liquidAddress: 'claim-address',
        absoluteFees: 12,
        cooperate: true,
      ),
    ).called(1);
  });
}
