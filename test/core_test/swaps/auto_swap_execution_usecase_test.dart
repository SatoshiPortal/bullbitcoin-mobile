import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/ports/blockchain_port.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/auto_swap_execution_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/liquid_tx_output.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_build_tx_exceptions.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBoltzSwapRepository extends Mock implements BoltzSwapRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockLiquidWalletRepository extends Mock
    implements LiquidWalletRepository {}

class _MockWalletUtxoRepository extends Mock implements WalletUtxoRepository {}

class _MockWalletAddressRepository extends Mock
    implements WalletAddressRepository {}

class _MockBlockchainPort extends Mock implements BlockchainPort {}

class _MockWalletTransactionRepository extends Mock
    implements WalletTransactionRepository {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

void main() {
  late _MockBoltzSwapRepository boltz;
  late _MockWalletRepository walletRepo;
  late _MockLiquidWalletRepository liquidRepo;
  late _MockWalletUtxoRepository utxoRepo;
  late _MockWalletAddressRepository addressRepo;
  late _MockBlockchainPort blockchainPort;
  late _MockWalletTransactionRepository walletTxRepo;
  late _MockLabelsFacade labelsFacade;
  late AutoSwapExecutionUsecase usecase;

  const liquidWalletId = 'liquid-wallet-1';
  const bitcoinWalletId = 'bitcoin-wallet-1';
  const changeAddress = 'lq1qqchange...';

  Wallet buildWallet({
    required String origin,
    required bool isLiquid,
    required BigInt balanceSat,
  }) => Wallet(
    origin: origin,
    network: isLiquid ? Network.liquidMainnet : Network.bitcoinMainnet,
    isDefault: true,
    xpubFingerprint: 'fingerprint',
    scriptType: ScriptType.bip84,
    xpub: 'xpub',
    externalPublicDescriptor: 'external-descriptor',
    internalPublicDescriptor: 'internal-descriptor',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: balanceSat,
  );

  final liquidWallet = buildWallet(
    origin: liquidWalletId,
    isLiquid: true,
    balanceSat: BigInt.from(3000000),
  );
  final bitcoinWallet = buildWallet(
    origin: bitcoinWalletId,
    isLiquid: false,
    balanceSat: BigInt.zero,
  );

  final chainSwap = ChainSwap(
    id: 'swap-1',
    keyIndex: 0,
    type: SwapType.liquidToBitcoin,
    status: SwapStatus.pending,
    environment: Environment.mainnet,
    creationTime: DateTime(2026),
    sendWalletId: liquidWalletId,
    paymentAddress: 'ex1qswaplockup...',
    paymentAmount: 2000000,
  );

  setUpAll(() {
    registerFallbackValue(const <LiquidTxOutput>[]);
    registerFallbackValue(const RelativeFee(25));
    registerFallbackValue(const AutoSwap());
    registerFallbackValue(
      NewLabel.tx(transactionId: 'fallback', label: 'fallback'),
    );
  });

  setUp(() {
    boltz = _MockBoltzSwapRepository();
    walletRepo = _MockWalletRepository();
    liquidRepo = _MockLiquidWalletRepository();
    utxoRepo = _MockWalletUtxoRepository();
    addressRepo = _MockWalletAddressRepository();
    blockchainPort = _MockBlockchainPort();
    walletTxRepo = _MockWalletTransactionRepository();
    labelsFacade = _MockLabelsFacade();
    usecase = AutoSwapExecutionUsecase(
      repository: boltz,
      walletRepository: walletRepo,
      liquidWalletRepository: liquidRepo,
      walletUtxoRepository: utxoRepo,
      walletAddressRepository: addressRepo,
      blockchainPort: blockchainPort,
      walletTxRepository: walletTxRepo,
      labelsFacade: labelsFacade,
    );

    when(() => boltz.getAutoSwapParams()).thenAnswer(
      (_) async => const AutoSwap(
        enabled: true,
        showWarning: false,
        recipientWalletId: bitcoinWalletId,
        triggerBalanceSats: 2000000,
        balanceThresholdSats: 1000000,
      ),
    );
    when(
      () => walletRepo.getWallets(environment: any(named: 'environment')),
    ).thenAnswer((_) async => [liquidWallet, bitcoinWallet]);
    when(() => boltz.getSwapLimitsAndFees(SwapType.liquidToBitcoin)).thenAnswer(
      (_) async =>
          (const SwapLimits(min: 1000, max: 10000000), const SwapFees()),
    );
    when(
      () => boltz.createLiquidToBitcoinSwap(
        sendWalletId: any(named: 'sendWalletId'),
        amountSat: any(named: 'amountSat'),
        btcElectrumUrl: any(named: 'btcElectrumUrl'),
        lbtcElectrumUrl: any(named: 'lbtcElectrumUrl'),
        receiveWalletId: any(named: 'receiveWalletId'),
      ),
    ).thenAnswer((_) async => chainSwap);
    when(
      () => liquidRepo.getConfirmedLbtcOutpoints(
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) async => [(txId: 'tx0', vout: 0)]);
    when(() => utxoRepo.getAllFrozenOutpoints()).thenAnswer((_) async => []);
    when(() => liquidRepo.exceedsLiquidInputLimit(any())).thenReturn(false);
    when(
      () => addressRepo.generateNewReceiveAddress(
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer(
      (_) async => WalletAddress(
        walletId: liquidWalletId,
        index: 1,
        address: changeAddress,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    when(
      () => liquidRepo.buildCustomTx(
        walletId: any(named: 'walletId'),
        utxos: any(named: 'utxos'),
        outputs: any(named: 'outputs'),
        drainToAddress: any(named: 'drainToAddress'),
        feeRate: any(named: 'feeRate'),
      ),
    ).thenAnswer((_) async => 'unsigned-pset');
    when(
      () => liquidRepo.getPsetSizeAndAbsoluteFees(pset: any(named: 'pset')),
    ).thenAnswer((_) async => (200, 50));
    when(
      () => liquidRepo.signPset(
        pset: any(named: 'pset'),
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) async => 'signed-pset');
    when(
      () => blockchainPort.broadcastLiquidTransaction(
        signedPset: any(named: 'signedPset'),
        isTestnet: any(named: 'isTestnet'),
      ),
    ).thenAnswer((_) async => 'txid-123');
    when(
      () => boltz.updatePaidSendSwap(
        swapId: any(named: 'swapId'),
        txid: any(named: 'txid'),
        absoluteFees: any(named: 'absoluteFees'),
      ),
    ).thenAnswer((_) async {});
    when(() => boltz.updateAutoSwapParams(any())).thenAnswer((_) async {});
    when(() => labelsFacade.store(any())).thenAnswer(
      (_) async =>
          Ok(Label.tx(id: 1, transactionId: 'txid-123', label: 'Auto-Swap')),
    );
    when(
      () => walletTxRepo.getWalletTransaction(
        any(),
        walletId: any(named: 'walletId'),
        sync: any(named: 'sync'),
      ),
    ).thenAnswer((_) async => null);
  });

  group('frozen-UTXO enforcement: an auto-swap lockup payment is a background, '
      'unattended send — a frozen UTXO (e.g. a consolidation decoy) must '
      'never be able to slip into it either', () {
    test(
      'excludes frozen outpoints from the utxos passed to buildCustomTx',
      () async {
        when(
          () => liquidRepo.getConfirmedLbtcOutpoints(
            walletId: any(named: 'walletId'),
          ),
        ).thenAnswer(
          (_) async => [
            (txId: 'tx0', vout: 0),
            (txId: 'tx1', vout: 0),
            (txId: 'tx2', vout: 0),
          ],
        );
        when(
          () => utxoRepo.getAllFrozenOutpoints(),
        ).thenAnswer((_) async => [(txId: 'tx1', vout: 0)]);

        await usecase.execute(feeBlock: false);

        final captured = verify(
          () => liquidRepo.buildCustomTx(
            walletId: liquidWalletId,
            utxos: captureAny(named: 'utxos'),
            outputs: any(named: 'outputs'),
            drainToAddress: any(named: 'drainToAddress'),
            feeRate: any(named: 'feeRate'),
          ),
        ).captured;
        final utxos = captured.single as List;
        expect(utxos, [(txId: 'tx0', vout: 0), (txId: 'tx2', vout: 0)]);
      },
    );

    test('throws NoSpendableUtxoException when every confirmed UTXO is '
        'frozen, never reaching buildCustomTx', () async {
      when(
        () => liquidRepo.getConfirmedLbtcOutpoints(
          walletId: any(named: 'walletId'),
        ),
      ).thenAnswer((_) async => [(txId: 'tx0', vout: 0)]);
      when(
        () => utxoRepo.getAllFrozenOutpoints(),
      ).thenAnswer((_) async => [(txId: 'tx0', vout: 0)]);

      await expectLater(
        usecase.execute(feeBlock: false),
        throwsA(isA<NoSpendableUtxoException>()),
      );
      verifyNever(
        () => liquidRepo.buildCustomTx(
          walletId: any(named: 'walletId'),
          utxos: any(named: 'utxos'),
          outputs: any(named: 'outputs'),
          drainToAddress: any(named: 'drainToAddress'),
          feeRate: any(named: 'feeRate'),
        ),
      );
    });

    test('throws LiquidInputLimitExceededException when the usable count '
        'exceeds the input limit', () async {
      when(
        () => liquidRepo.getConfirmedLbtcOutpoints(
          walletId: any(named: 'walletId'),
        ),
      ).thenAnswer(
        (_) async => List.generate(300, (i) => (txId: 'tx$i', vout: 0)),
      );
      when(() => liquidRepo.exceedsLiquidInputLimit(300)).thenReturn(true);

      await expectLater(
        usecase.execute(feeBlock: false),
        throwsA(isA<LiquidInputLimitExceededException>()),
      );
    });
  });

  test('the swap lockup output and reserved change address are exactly what '
      'gets passed to buildCustomTx', () async {
    await usecase.execute(feeBlock: false);

    final captured = verify(
      () => liquidRepo.buildCustomTx(
        walletId: liquidWalletId,
        utxos: any(named: 'utxos'),
        outputs: captureAny(named: 'outputs'),
        drainToAddress: captureAny(named: 'drainToAddress'),
        feeRate: any(named: 'feeRate'),
      ),
    ).captured;
    final outputs = captured[0] as List<LiquidTxOutput>;
    expect(outputs, hasLength(1));
    expect(outputs.single.address, chainSwap.paymentAddress);
    expect(outputs.single.satoshi, chainSwap.paymentAmount);
    expect(captured[1], changeAddress);
  });
}
