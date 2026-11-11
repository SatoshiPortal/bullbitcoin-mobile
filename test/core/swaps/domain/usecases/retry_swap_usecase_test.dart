import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/retry_swap_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBoltzSwapRepository extends Mock implements BoltzSwapRepository {}

class _MockGetNetworkFeesUsecase extends Mock
    implements GetNetworkFeesUsecase {}

class _MockWalletAddressRepository extends Mock
    implements WalletAddressRepository {}

void main() {
  late _MockBoltzSwapRepository repo;
  late _MockGetNetworkFeesUsecase getNetworkFees;
  late _MockWalletAddressRepository walletAddresses;
  late RetrySwapUsecase usecase;

  setUpAll(() {
    registerFallbackValue(SwapType.bitcoinToLightning);
  });

  setUp(() {
    repo = _MockBoltzSwapRepository();
    getNetworkFees = _MockGetNetworkFeesUsecase();
    walletAddresses = _MockWalletAddressRepository();
    usecase = RetrySwapUsecase(
      boltzSwapRepository: repo,
      getNetworkFeesUsecase: getNetworkFees,
      walletAddressRepository: walletAddresses,
    );

    when(
      () => repo.updateSwapFields(
        any(),
        status: any(named: 'status'),
        receiveTxid: any(named: 'receiveTxid'),
        refundTxid: any(named: 'refundTxid'),
        receiveAddress: any(named: 'receiveAddress'),
        refundAddress: any(named: 'refundAddress'),
        preimage: any(named: 'preimage'),
        claimFee: any(named: 'claimFee'),
        refundFee: any(named: 'refundFee'),
        completionTime: any(named: 'completionTime'),
      ),
    ).thenAnswer((_) async => _lnSend(status: SwapStatus.refunded));
  });

  // Every retry must resolve on the script path with the Boltz API treated as
  // dead: cooperative signing OFF, fees computed locally, and none of the
  // Boltz-touching repo methods called.
  void verifyNoBoltzApiCalls() {
    verifyNever(
      () => repo.coopSignBitcoinToLightningSwap(swapId: any(named: 'swapId')),
    );
    verifyNever(
      () => repo.coopSignLiquidToLightningSwap(swapId: any(named: 'swapId')),
    );
    verifyNever(() => repo.reconcileSwaps(any()));
    verifyNever(() => repo.subscribeToSwaps(any()));
    verifyNever(() => repo.getSwapLimitsAndFees(any()));
  }

  group('RetrySwapUsecase — script path only, no Boltz API', () {
    test('refunds a submarine swap non-cooperatively, fee floored when the '
        'fee API is down', () async {
      final swap = _lnSend(status: SwapStatus.refundable);
      when(
        () => repo.getSwapRefundTxSize(
          swapId: 'swap-1',
          swapType: SwapType.bitcoinToLightning,
          isCooperative: false,
          refundAddressForChainSwaps: null,
        ),
      ).thenAnswer((_) async => 150);
      // Boltz is dead; the mempool fee estimate is also unreachable, so the
      // usecase must fall back to the relay floor (1 sat/vb on bitcoin).
      when(
        () => getNetworkFees.execute(isLiquid: any(named: 'isLiquid')),
      ).thenThrow(Exception('fee api down'));
      when(
        () => repo.refundBitcoinToLightningSwap(
          swapId: any(named: 'swapId'),
          bitcoinAddress: any(named: 'bitcoinAddress'),
          absoluteFees: any(named: 'absoluteFees'),
          cooperate: any(named: 'cooperate'),
        ),
      ).thenAnswer((_) async => 'refund-txid');
      when(() => repo.getSwap(swapId: 'swap-1')).thenAnswer((_) async => swap);

      await usecase.execute(swap);

      verify(
        () => repo.getSwapRefundTxSize(
          swapId: 'swap-1',
          swapType: SwapType.bitcoinToLightning,
          isCooperative: false,
          refundAddressForChainSwaps: null,
        ),
      ).called(1);
      verify(
        () => repo.refundBitcoinToLightningSwap(
          swapId: 'swap-1',
          bitcoinAddress: 'bc1qrefund',
          absoluteFees: 150,
          cooperate: false,
        ),
      ).called(1);
      verifyNoBoltzApiCalls();
    });

    test(
      'claims a reverse swap non-cooperatively to its receive address',
      () async {
        final swap = _lnReceive(status: SwapStatus.claimable);
        when(
          () => repo.getSwapClaimTxSize(
            swapId: 'swap-2',
            swapType: SwapType.lightningToBitcoin,
            isCooperative: false,
            claimAddressForChainSwaps: null,
          ),
        ).thenAnswer((_) async => 120);
        when(
          () => getNetworkFees.execute(isLiquid: any(named: 'isLiquid')),
        ).thenThrow(Exception('fee api down'));
        when(
          () => repo.claimLightningToBitcoinSwap(
            swapId: any(named: 'swapId'),
            bitcoinAddress: any(named: 'bitcoinAddress'),
            absoluteFees: any(named: 'absoluteFees'),
            cooperate: any(named: 'cooperate'),
          ),
        ).thenAnswer((_) async => 'claim-txid');
        when(
          () => repo.getSwap(swapId: 'swap-2'),
        ).thenAnswer((_) async => swap);

        await usecase.execute(swap);

        verify(
          () => repo.getSwapClaimTxSize(
            swapId: 'swap-2',
            swapType: SwapType.lightningToBitcoin,
            isCooperative: false,
            claimAddressForChainSwaps: null,
          ),
        ).called(1);
        verify(
          () => repo.claimLightningToBitcoinSwap(
            swapId: 'swap-2',
            bitcoinAddress: 'bc1qclaim',
            absoluteFees: 120,
            cooperate: false,
          ),
        ).called(1);
        verifyNever(
          () => repo.refundBitcoinToLightningSwap(
            swapId: any(named: 'swapId'),
            bitcoinAddress: any(named: 'bitcoinAddress'),
            absoluteFees: any(named: 'absoluteFees'),
            cooperate: any(named: 'cooperate'),
          ),
        );
        verifyNoBoltzApiCalls();
      },
    );
  });
}

LnSendSwap _lnSend({required SwapStatus status}) =>
    Swap.lnSend(
          id: 'swap-1',
          keyIndex: 0,
          type: SwapType.bitcoinToLightning,
          status: status,
          environment: Environment.mainnet,
          creationTime: DateTime(2024),
          sendWalletId: 'w1',
          invoice: 'lnbc1',
          paymentAddress: 'bc1qlockup',
          paymentAmount: 100000,
          refundAddress: 'bc1qrefund',
        )
        as LnSendSwap;

LnReceiveSwap _lnReceive({required SwapStatus status}) =>
    Swap.lnReceive(
          id: 'swap-2',
          keyIndex: 0,
          type: SwapType.lightningToBitcoin,
          status: status,
          environment: Environment.mainnet,
          creationTime: DateTime(2024),
          receiveWalletId: 'w1',
          invoice: 'lnbc2',
          receiveAddress: 'bc1qclaim',
        )
        as LnReceiveSwap;
