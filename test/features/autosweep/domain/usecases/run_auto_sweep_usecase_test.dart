import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/autosweep/domain/autosweep_error.dart';
import 'package:bb_mobile/features/autosweep/domain/autosweep_fee_policy.dart';
import 'package:bb_mobile/features/autosweep/domain/autosweep_result.dart';
import 'package:bb_mobile/features/autosweep/domain/autosweep_wallet_port.dart';
import 'package:bb_mobile/features/autosweep/domain/usecases/run_auto_sweep_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAutosweepWalletPort extends Mock implements AutosweepWalletPort {}

class _MockBroadcastLiquidTransactionUsecase extends Mock
    implements BroadcastLiquidTransactionUsecase {}

class _MockBroadcastBitcoinTransactionUsecase extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

class _MockGetNetworkFeesUsecase extends Mock
    implements GetNetworkFeesUsecase {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

void main() {
  setUpAll(() {
    registerFallbackValue(const NetworkFee.relative(0.1));
    registerFallbackValue(NewLabel.tx(transactionId: 'txid', label: 'label'));
    registerFallbackValue(
      _wallet(id: 'fallback', network: Network.liquidMainnet),
    );
  });

  late _MockAutosweepWalletPort wallets;
  late _MockBroadcastLiquidTransactionUsecase broadcastLiquid;
  late _MockBroadcastBitcoinTransactionUsecase broadcastBitcoin;
  late _MockGetNetworkFeesUsecase getNetworkFees;
  late _MockLabelsFacade labelsFacade;
  late RunAutoSweepUsecase usecase;

  setUp(() {
    wallets = _MockAutosweepWalletPort();
    broadcastLiquid = _MockBroadcastLiquidTransactionUsecase();
    broadcastBitcoin = _MockBroadcastBitcoinTransactionUsecase();
    getNetworkFees = _MockGetNetworkFeesUsecase();
    labelsFacade = _MockLabelsFacade();
    usecase = RunAutoSweepUsecase(
      wallets: wallets,
      broadcastLiquid: broadcastLiquid,
      broadcastBitcoin: broadcastBitcoin,
      getNetworkFees: getNetworkFees,
      labelsFacade: labelsFacade,
      feePolicy: const AutosweepFeePolicy(),
    );

    when(() => labelsFacade.store(any())).thenAnswer(
      (_) async => Label.tx(id: 1, transactionId: 'txid', label: ''),
    );
  });

  test('sweeps enabled Liquid wallet to default Liquid wallet', () async {
    final source = _wallet(
      id: 'btcpay-liquid',
      network: Network.liquidMainnet,
      autoSweepEnabled: true,
      balanceSat: BigInt.from(1000),
    );
    when(
      () => wallets.getDefaultWallet(
        sourceWallet: source,
        onlyBitcoin: false,
        onlyLiquid: true,
      ),
    ).thenAnswer(
      (_) async => _wallet(
        id: 'default-liquid',
        network: Network.liquidMainnet,
        isDefault: true,
      ),
    );
    when(
      () => wallets.getCurrentReceiveAddress(walletId: 'default-liquid'),
    ).thenAnswer((_) async => 'lq1destination');
    when(
      () => wallets.buildLiquidDrainPset(
        walletId: 'btcpay-liquid',
        address: 'lq1destination',
        networkFee: const NetworkFee.relative(0.1),
      ),
    ).thenAnswer((_) async => 'pset');
    when(
      () => wallets.signLiquidPset(pset: 'pset', walletId: 'btcpay-liquid'),
    ).thenAnswer((_) async => 'signed-pset');
    when(
      () => broadcastLiquid.execute('signed-pset', isTestnet: false),
    ).thenAnswer((_) async => 'txid');

    final result = await usecase.execute(source);

    expect(result, isA<AutosweepSwept>());
    expect((result as AutosweepSwept).txid, 'txid');
    verify(
      () => wallets.buildLiquidDrainPset(
        walletId: 'btcpay-liquid',
        address: 'lq1destination',
        networkFee: const NetworkFee.relative(0.1),
      ),
    ).called(1);
    verify(() => labelsFacade.store(any())).called(1);
  });

  test('skips Bitcoin sweep when fee exceeds autosweep policy', () async {
    final source = _wallet(
      id: 'btcpay-bitcoin',
      network: Network.bitcoinMainnet,
      autoSweepEnabled: true,
      balanceSat: BigInt.from(1000),
    );
    when(
      () => wallets.getDefaultWallet(
        sourceWallet: source,
        onlyBitcoin: true,
        onlyLiquid: false,
      ),
    ).thenAnswer(
      (_) async => _wallet(
        id: 'default-bitcoin',
        network: Network.bitcoinMainnet,
        isDefault: true,
      ),
    );
    when(
      () => wallets.getCurrentReceiveAddress(walletId: 'default-bitcoin'),
    ).thenAnswer((_) async => 'bc1destination');
    when(() => getNetworkFees.execute(isLiquid: false)).thenAnswer(
      (_) async => const FeeOptions(
        fastest: NetworkFee.relative(10),
        economic: NetworkFee.relative(2),
        slow: NetworkFee.relative(1),
      ),
    );
    when(
      () => wallets.buildBitcoinDrainPsbt(
        walletId: 'btcpay-bitcoin',
        address: 'bc1destination',
        networkFee: const NetworkFee.relative(2),
      ),
    ).thenAnswer((_) async => 'psbt');
    when(
      () => wallets.getBitcoinFeeSat(psbt: 'psbt'),
    ).thenAnswer((_) async => 100);

    final result = await usecase.execute(source);

    expect(result, const AutosweepSkipped(AutosweepSkipReason.feePolicy));
    verifyNever(
      () => wallets.signBitcoinPsbt(
        psbt: any(named: 'psbt'),
        walletId: any(named: 'walletId'),
      ),
    );
    verifyNever(
      () => broadcastBitcoin.execute(any(), isPsbt: any(named: 'isPsbt')),
    );
    verifyNever(() => labelsFacade.store(any()));
  });

  test('skips dust balances below the sweep threshold', () async {
    final result = await usecase.execute(
      _wallet(
        id: 'btcpay-liquid',
        network: Network.liquidMainnet,
        autoSweepEnabled: true,
        balanceSat: BigInt.from(100),
      ),
    );

    expect(result, const AutosweepSkipped(AutosweepSkipReason.dust));
  });

  test('skips when no default wallet exists for the network', () async {
    final source = _wallet(
      id: 'btcpay-liquid',
      network: Network.liquidMainnet,
      autoSweepEnabled: true,
      balanceSat: BigInt.from(1000),
    );
    when(
      () => wallets.getDefaultWallet(
        sourceWallet: source,
        onlyBitcoin: false,
        onlyLiquid: true,
      ),
    ).thenAnswer((_) async => null);

    final result = await usecase.execute(source);

    expect(
      result,
      const AutosweepSkipped(AutosweepSkipReason.noDefaultWallet),
    );
  });

  test('reports a failed outcome when a wallet operation throws', () async {
    final source = _wallet(
      id: 'btcpay-liquid',
      network: Network.liquidMainnet,
      autoSweepEnabled: true,
      balanceSat: BigInt.from(1000),
    );
    when(
      () => wallets.getDefaultWallet(
        sourceWallet: source,
        onlyBitcoin: false,
        onlyLiquid: true,
      ),
    ).thenThrow(
      AutosweepWalletOperationException(
        'Autosweep default wallet lookup failed',
      ),
    );

    final result = await usecase.execute(source);

    expect(result, isA<AutosweepFailed>());
    expect(
      (result as AutosweepFailed).error,
      isA<AutosweepWalletOperationException>(),
    );
    verifyNever(() => labelsFacade.store(any()));
  });

  test('reports a failed outcome when broadcasting throws raw', () async {
    final source = _wallet(
      id: 'btcpay-liquid',
      network: Network.liquidMainnet,
      autoSweepEnabled: true,
      balanceSat: BigInt.from(1000),
    );
    when(
      () => wallets.getDefaultWallet(
        sourceWallet: source,
        onlyBitcoin: false,
        onlyLiquid: true,
      ),
    ).thenAnswer(
      (_) async => _wallet(
        id: 'default-liquid',
        network: Network.liquidMainnet,
        isDefault: true,
      ),
    );
    when(
      () => wallets.getCurrentReceiveAddress(walletId: 'default-liquid'),
    ).thenAnswer((_) async => 'lq1destination');
    when(
      () => wallets.buildLiquidDrainPset(
        walletId: 'btcpay-liquid',
        address: 'lq1destination',
        networkFee: const NetworkFee.relative(0.1),
      ),
    ).thenAnswer((_) async => 'pset');
    when(
      () => wallets.signLiquidPset(pset: 'pset', walletId: 'btcpay-liquid'),
    ).thenAnswer((_) async => 'signed-pset');
    when(
      () => broadcastLiquid.execute('signed-pset', isTestnet: false),
    ).thenThrow(Exception('electrum down'));

    final result = await usecase.execute(source);

    expect(result, isA<AutosweepFailed>());
    expect(
      (result as AutosweepFailed).error,
      isA<AutosweepUnexpectedException>(),
    );
    verifyNever(() => labelsFacade.store(any()));
  });

  test('does not sweep wallets without auto-sweep enabled', () async {
    final result = await usecase.execute(
      _wallet(id: 'manual', network: Network.liquidMainnet),
    );

    expect(result, const AutosweepSkipped(AutosweepSkipReason.disabled));
    verifyNever(
      () => wallets.getDefaultWallet(
        sourceWallet: any(named: 'sourceWallet'),
        onlyBitcoin: any(named: 'onlyBitcoin'),
        onlyLiquid: any(named: 'onlyLiquid'),
      ),
    );
  });
}

Wallet _wallet({
  required String id,
  required Network network,
  bool isDefault = false,
  bool autoSweepEnabled = false,
  BigInt? balanceSat,
}) {
  return Wallet(
    origin: id,
    label: id,
    network: network,
    isDefault: isDefault,
    masterFingerprint: 'fingerprint',
    xpubFingerprint: 'xpub-fingerprint',
    scriptType: ScriptType.bip84,
    xpub: 'xpub',
    externalPublicDescriptor: 'external-desc',
    internalPublicDescriptor: 'internal-desc',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: balanceSat ?? BigInt.from(1000),
    autoSweepEnabled: autoSweepEnabled,
  );
}
