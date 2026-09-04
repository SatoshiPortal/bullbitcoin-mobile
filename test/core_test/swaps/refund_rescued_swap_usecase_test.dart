import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
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

class _FakeElectrumServersPort implements ElectrumServersPort {
  static const connection = ElectrumConnection(
    url: 'ssl://working.electrum:50002',
    retry: 1,
    timeout: 10,
    stopGap: 20,
    validateDomain: true,
    isCustom: false,
  );

  @override
  Future<T> runWithFallback<T>({
    required ElectrumServerNetwork network,
    required Future<T> Function(ElectrumConnection connection) operation,
    bool Function(Object error)? isTransient,
  }) => operation(connection);
}

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
    electrumServersPort: _FakeElectrumServersPort(),
  );

  setUpAll(() {
    registerFallbackValue(SwapType.liquidToBitcoin);
    registerFallbackValue(Network.liquidMainnet);
    registerFallbackValue(SwapStatus.refunded);
    registerFallbackValue(SwapDirection.liquidToBitcoin);
    registerFallbackValue(_FakeElectrumServersPort.connection);
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
        electrum: any(named: 'electrum'),
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
        electrum: any(named: 'electrum'),
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
    'Boltz down: cooperative refund fails, script path settles via electrum',
    () async {
      // Cooperation needs the Boltz API; with it down the coop broadcast
      // throws a connection error. The script path is Boltz-free (electrum
      // UTXO + local signature + electrum broadcast) and must finish the
      // refund on its own.
      when(
        () => swapRepo.refundLiquidToBitcoinSwap(
          swapId: any(named: 'swapId'),
          liquidRefundAddress: any(named: 'liquidRefundAddress'),
          absoluteFees: any(named: 'absoluteFees'),
          cooperate: true,
          electrum: any(named: 'electrum'),
        ),
      ).thenThrow(Exception('Connection refused (boltz api unreachable)'));
      when(
        () => swapRepo.refundLiquidToBitcoinSwap(
          swapId: any(named: 'swapId'),
          liquidRefundAddress: any(named: 'liquidRefundAddress'),
          absoluteFees: any(named: 'absoluteFees'),
          cooperate: false,
          electrum: any(named: 'electrum'),
        ),
      ).thenAnswer((_) async => 'script-refund-txid');

      final txid = await usecase().execute(chainSwap());

      expect(txid, 'script-refund-txid');
      verify(
        () => swapRepo.updateSwapFields(
          'D5gdAL9UI29W',
          status: SwapStatus.refunded,
          refundTxid: 'script-refund-txid',
          refundAddress: 'lq1refund',
          refundFee: any(named: 'refundFee'),
          completionTime: any(named: 'completionTime'),
        ),
      ).called(1);
    },
  );

  test('fee API down: falls back to the relay-floor fee', () async {
    when(
      () => feesRepo.getNetworkFees(network: any(named: 'network')),
    ).thenThrow(Exception('mempool api unreachable'));
    when(
      () => swapRepo.refundLiquidToBitcoinSwap(
        swapId: any(named: 'swapId'),
        liquidRefundAddress: any(named: 'liquidRefundAddress'),
        absoluteFees: any(named: 'absoluteFees'),
        cooperate: any(named: 'cooperate'),
        electrum: any(named: 'electrum'),
      ),
    ).thenAnswer((_) async => 'refund-txid');

    await usecase().execute(chainSwap());

    // Liquid floor for txSize=200: ceil(200 * 0.11) + 1 = 23 sats.
    verify(
      () => swapRepo.refundLiquidToBitcoinSwap(
        swapId: 'D5gdAL9UI29W',
        liquidRefundAddress: 'lq1refund',
        absoluteFees: 23,
        cooperate: true,
        electrum: any(named: 'electrum'),
      ),
    ).called(1);
  });

  test('executeAllRefundable drives local refundable swaps and survives '
      'per-swap failure (Boltz fully down)', () async {
    ChainSwap swapWithId(String id) =>
        (chainSwap() as Swap).copyWith(id: id) as ChainSwap;
    final failing = swapWithId('failingSwap1');
    final succeeding = swapWithId('workingSwap1');
    when(
      () => swapRepo.getAllSwaps(),
    ).thenAnswer((_) async => [failing, succeeding]);
    // First swap: everything Boltz-adjacent throws, outspend check too.
    when(
      () => swapRepo.refundLiquidToBitcoinSwap(
        swapId: 'failingSwap1',
        liquidRefundAddress: any(named: 'liquidRefundAddress'),
        absoluteFees: any(named: 'absoluteFees'),
        cooperate: any(named: 'cooperate'),
        electrum: any(named: 'electrum'),
      ),
    ).thenThrow(Exception('boltz api down'));
    when(
      () => swapRepo.checkLockupOutspends(
        swapId: any(named: 'swapId'),
        swapType: any(named: 'swapType'),
        network: any(named: 'network'),
        swapDirection: any(named: 'swapDirection'),
        isClaim: any(named: 'isClaim'),
      ),
    ).thenThrow(Exception('boltz api down'));
    // Second swap: script path lands.
    when(
      () => swapRepo.refundLiquidToBitcoinSwap(
        swapId: 'workingSwap1',
        liquidRefundAddress: any(named: 'liquidRefundAddress'),
        absoluteFees: any(named: 'absoluteFees'),
        cooperate: any(named: 'cooperate'),
        electrum: any(named: 'electrum'),
      ),
    ).thenAnswer((_) async => 'refund-b');

    await usecase().executeAllRefundable();

    verify(
      () => swapRepo.updateSwapFields(
        'workingSwap1',
        status: SwapStatus.refunded,
        refundTxid: 'refund-b',
        refundAddress: 'lq1refund',
        refundFee: any(named: 'refundFee'),
        completionTime: any(named: 'completionTime'),
      ),
    ).called(1);
    verifyNever(
      () => swapRepo.updateSwapFields(
        'failingSwap1',
        status: any(named: 'status'),
        refundTxid: any(named: 'refundTxid'),
        refundAddress: any(named: 'refundAddress'),
        refundFee: any(named: 'refundFee'),
        completionTime: any(named: 'completionTime'),
      ),
    );
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
          electrum: any(named: 'electrum'),
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

  test('does NOT settle on a spend of the lockup change output '
      '(in-wallet but outgoing)', () async {
    // The outspend report covers every vout of the lockup tx, so the
    // wallet's own change output spent by an ordinary consolidation shows
    // up too — and that tx IS in our wallet. It is outgoing, not a refund;
    // settling on it would hide the still-locked covenant funds forever.
    when(
      () => swapRepo.refundLiquidToBitcoinSwap(
        swapId: any(named: 'swapId'),
        liquidRefundAddress: any(named: 'liquidRefundAddress'),
        absoluteFees: any(named: 'absoluteFees'),
        cooperate: any(named: 'cooperate'),
        electrum: any(named: 'electrum'),
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
      (_) async => const [SwapTxOutspend(txid: 'change-consolidation')],
    );
    when(
      () => txRepo.getWalletTransaction(
        'change-consolidation',
        walletId: 'w-liquid',
      ),
    ).thenAnswer(
      (_) async => const WalletTransaction(
        walletId: 'w-liquid',
        network: Network.liquidMainnet,
        direction: WalletTransactionDirection.outgoing,
        status: WalletTransactionStatus.confirmed,
        txId: 'change-consolidation',
        amountSat: 50000,
        feeSat: 100,
        vsize: 300,
        inputs: [],
        outputs: [],
        isRbf: false,
      ),
    );

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
  });

  test(
    'non-final (timelock) failure skips outspend recovery entirely',
    () async {
      when(
        () => swapRepo.refundLiquidToBitcoinSwap(
          swapId: any(named: 'swapId'),
          liquidRefundAddress: any(named: 'liquidRefundAddress'),
          absoluteFees: any(named: 'absoluteFees'),
          cooperate: any(named: 'cooperate'),
          electrum: any(named: 'electrum'),
        ),
      ).thenThrow(Exception('non-BIP68-final'));

      await expectLater(
        usecase().execute(chainSwap()),
        throwsA(isA<RefundRescuedSwapException>()),
      );
      // Before the timelock nothing of ours can be on-chain: the recovery must
      // not even look, or it could only ever match an unrelated spend.
      verifyNever(
        () => swapRepo.checkLockupOutspends(
          swapId: any(named: 'swapId'),
          swapType: any(named: 'swapType'),
          network: any(named: 'network'),
          swapDirection: any(named: 'swapDirection'),
          isClaim: any(named: 'isClaim'),
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
        electrum: any(named: 'electrum'),
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
