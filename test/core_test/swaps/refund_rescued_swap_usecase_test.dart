import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap_tx_outspend.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/refund_rescued_swap_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBoltzSwapRepository extends Mock implements BoltzSwapRepository {}

class _MockWalletAddressRepository extends Mock
    implements WalletAddressRepository {}

class _MockWalletTransactionRepository extends Mock
    implements WalletTransactionRepository {}

class _MockFeesRepository extends Mock implements FeesRepository {}

void main() {
  late _MockBoltzSwapRepository swapRepo;
  late _MockWalletAddressRepository addressRepo;
  late _MockWalletTransactionRepository txRepo;
  late _MockFeesRepository feesRepo;

  ChainSwap chainSwap({
    String? refundTxid,
    String? refundAddress = 'lq1refund',
  }) =>
      Swap.chain(
            id: 'D5gdAL9UI29W',
            keyIndex: 0,
            type: SwapType.liquidToBitcoin,
            status: SwapStatus.refundable,
            environment: Environment.mainnet,
            creationTime: DateTime(2026, 7),
            sendWalletId: 'w-liquid',
            paymentAddress: 'lq1lockup',
            paymentAmount: 100000,
            sendTxid: 'lockup-txid',
            refundAddress: refundAddress,
            refundTxid: refundTxid,
          )
          as ChainSwap;

  RefundRescuedSwapUsecase usecase() => RefundRescuedSwapUsecase(
    swapRepository: swapRepo,
    walletAddressRepository: addressRepo,
    walletTransactionRepository: txRepo,
    feesRepository: feesRepo,
  );

  setUpAll(() {
    registerFallbackValue(SwapType.liquidToBitcoin);
    registerFallbackValue(Network.liquidMainnet);
    registerFallbackValue(SwapStatus.refunded);
    registerFallbackValue(SwapDirection.liquidToBitcoin);
  });

  setUp(() {
    swapRepo = _MockBoltzSwapRepository();
    addressRepo = _MockWalletAddressRepository();
    txRepo = _MockWalletTransactionRepository();
    feesRepo = _MockFeesRepository();

    when(
      () => feesRepo.getNetworkFees(network: any(named: 'network')),
    ).thenAnswer(
      (_) async => FeeOptions(
        fastest: const NetworkFee.absolute(50),
        economic: const NetworkFee.absolute(30),
        slow: const NetworkFee.absolute(10),
        minRelay: NetworkFee.relativeFromSatPerVbyte(0.1),
      ),
    );
    when(
      () => swapRepo.getSwapRefundTxSize(
        swapId: any(named: 'swapId'),
        swapType: any(named: 'swapType'),
        isCooperative: any(named: 'isCooperative'),
        refundAddressForChainSwaps: any(named: 'refundAddressForChainSwaps'),
      ),
    ).thenAnswer((_) async => 200);
    when(
      () => swapRepo.updateSwapFields(
        any(),
        status: any(named: 'status'),
        refundTxid: any(named: 'refundTxid'),
        refundAddress: any(named: 'refundAddress'),
        refundFee: any(named: 'refundFee'),
        completionTime: any(named: 'completionTime'),
      ),
    ).thenAnswer((invocation) async => chainSwap(refundTxid: 'stored'));
  });

  test('broadcasts the refund and settles the swap', () async {
    when(
      () => swapRepo.refundLiquidToBitcoinSwap(
        swapId: any(named: 'swapId'),
        liquidRefundAddress: any(named: 'liquidRefundAddress'),
        absoluteFees: any(named: 'absoluteFees'),
        cooperate: any(named: 'cooperate'),
      ),
    ).thenAnswer((_) async => 'refund-txid');

    final txid = await usecase().execute(chainSwap());

    expect(txid, 'refund-txid');
    verify(
      () => swapRepo.updateSwapFields(
        'D5gdAL9UI29W',
        status: SwapStatus.refunded,
        refundTxid: 'refund-txid',
        refundAddress: 'lq1refund',
        refundFee: any(named: 'refundFee'),
        completionTime: any(named: 'completionTime'),
      ),
    ).called(1);
  });

  test(
    'does NOT settle on an outspend whose spender is not in our wallet',
    () async {
      // The D5gdAL9UI29W failure shape: broadcast fails, the lockup reads as
      // spent — but the spender is Boltz's own tx, not ours. The swap must
      // stay refundable, never settle on a stranger's txid.
      when(
        () => swapRepo.refundLiquidToBitcoinSwap(
          swapId: any(named: 'swapId'),
          liquidRefundAddress: any(named: 'liquidRefundAddress'),
          absoluteFees: any(named: 'absoluteFees'),
          cooperate: any(named: 'cooperate'),
        ),
      ).thenThrow(Exception('broadcast failed'));
      when(
        () => swapRepo.checkLockupOutspends(
          swapId: any(named: 'swapId'),
          swapType: any(named: 'swapType'),
          network: any(named: 'network'),
          swapDirection: any(named: 'swapDirection'),
          isClaim: any(named: 'isClaim'),
        ),
      ).thenAnswer(
        (_) async => const [SwapTxOutspend(txid: 'boltz-own-refund')],
      );
      when(
        () => txRepo.getWalletTransaction(
          'boltz-own-refund',
          walletId: 'w-liquid',
        ),
      ).thenAnswer((_) async => null);

      await expectLater(
        usecase().execute(chainSwap()),
        throwsA(isA<RefundRescuedSwapException>()),
      );
      verifyNever(
        () => swapRepo.updateSwapFields(
          any(),
          status: any(named: 'status'),
          refundTxid: any(named: 'refundTxid'),
          completionTime: any(named: 'completionTime'),
        ),
      );
    },
  );

  test('settles on an already-spent lockup when the spender is ours', () async {
    when(
      () => swapRepo.refundLiquidToBitcoinSwap(
        swapId: any(named: 'swapId'),
        liquidRefundAddress: any(named: 'liquidRefundAddress'),
        absoluteFees: any(named: 'absoluteFees'),
        cooperate: any(named: 'cooperate'),
      ),
    ).thenThrow(Exception('bad-txns-inputs-missingorspent'));
    when(
      () => swapRepo.checkLockupOutspends(
        swapId: any(named: 'swapId'),
        swapType: any(named: 'swapType'),
        network: any(named: 'network'),
        swapDirection: any(named: 'swapDirection'),
        isClaim: any(named: 'isClaim'),
      ),
    ).thenAnswer((_) async => const [SwapTxOutspend(txid: 'our-refund')]);
    when(
      () => txRepo.getWalletTransaction('our-refund', walletId: 'w-liquid'),
    ).thenAnswer(
      (_) async => const WalletTransaction(
        walletId: 'w-liquid',
        network: Network.liquidMainnet,
        direction: WalletTransactionDirection.incoming,
        status: WalletTransactionStatus.confirmed,
        txId: 'our-refund',
        amountSat: 99000,
        feeSat: 100,
        vsize: 200,
        inputs: [],
        outputs: [],
        isRbf: false,
      ),
    );
    when(
      () => swapRepo.updateSwapFields(
        any(),
        status: any(named: 'status'),
        refundTxid: any(named: 'refundTxid'),
        completionTime: any(named: 'completionTime'),
      ),
    ).thenAnswer((_) async => chainSwap(refundTxid: 'our-refund'));

    final txid = await usecase().execute(chainSwap());

    expect(txid, 'our-refund');
  });
}
