import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/features/autosweep/application/autosweep_fee_policy.dart';
import 'package:bb_mobile/features/autosweep/application/run_auto_sweep_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockWalletAddressRepository extends Mock
    implements WalletAddressRepository {}

class _MockLiquidWalletRepository extends Mock
    implements LiquidWalletRepository {}

class _MockBitcoinWalletRepository extends Mock
    implements BitcoinWalletRepository {}

class _MockBroadcastLiquidTransactionUsecase extends Mock
    implements BroadcastLiquidTransactionUsecase {}

class _MockBroadcastBitcoinTransactionUsecase extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

class _MockGetNetworkFeesUsecase extends Mock
    implements GetNetworkFeesUsecase {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

void main() {
  setUpAll(() {
    registerFallbackValue(Environment.mainnet);
    registerFallbackValue(const NetworkFee.relative(0.1));
    registerFallbackValue(NewLabel.tx(transactionId: 'txid', label: 'label'));
  });

  late _MockWalletRepository walletRepository;
  late _MockWalletAddressRepository walletAddressRepository;
  late _MockLiquidWalletRepository liquidWalletRepository;
  late _MockBitcoinWalletRepository bitcoinWalletRepository;
  late _MockBroadcastLiquidTransactionUsecase broadcastLiquid;
  late _MockBroadcastBitcoinTransactionUsecase broadcastBitcoin;
  late _MockGetNetworkFeesUsecase getNetworkFees;
  late _MockLabelsFacade labelsFacade;
  late RunAutoSweepUsecase usecase;

  setUp(() {
    walletRepository = _MockWalletRepository();
    walletAddressRepository = _MockWalletAddressRepository();
    liquidWalletRepository = _MockLiquidWalletRepository();
    bitcoinWalletRepository = _MockBitcoinWalletRepository();
    broadcastLiquid = _MockBroadcastLiquidTransactionUsecase();
    broadcastBitcoin = _MockBroadcastBitcoinTransactionUsecase();
    getNetworkFees = _MockGetNetworkFeesUsecase();
    labelsFacade = _MockLabelsFacade();
    usecase = RunAutoSweepUsecase(
      walletRepository: walletRepository,
      walletAddressRepository: walletAddressRepository,
      liquidWalletRepository: liquidWalletRepository,
      bitcoinWalletRepository: bitcoinWalletRepository,
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
      () => walletRepository.getWallets(
        environment: Environment.mainnet,
        onlyDefaults: true,
        onlyBitcoin: false,
        onlyLiquid: true,
      ),
    ).thenAnswer(
      (_) async => [
        _wallet(
          id: 'default-liquid',
          network: Network.liquidMainnet,
          isDefault: true,
        ),
      ],
    );
    when(
      () => walletAddressRepository.getLastRevealedReceiveAddress(
        walletId: 'default-liquid',
      ),
    ).thenAnswer((_) async => _address('default-liquid', 'lq1destination'));
    when(
      () => liquidWalletRepository.buildPset(
        walletId: 'btcpay-liquid',
        address: 'lq1destination',
        networkFee: const NetworkFee.relative(0.1),
        drain: true,
      ),
    ).thenAnswer((_) async => 'pset');
    when(
      () => liquidWalletRepository.signPset(
        pset: 'pset',
        walletId: 'btcpay-liquid',
      ),
    ).thenAnswer((_) async => 'signed-pset');
    when(
      () => broadcastLiquid.execute('signed-pset', isTestnet: false),
    ).thenAnswer((_) async => 'txid');

    final txid = await usecase.execute(source);

    expect(txid, 'txid');
    verify(
      () => liquidWalletRepository.buildPset(
        walletId: 'btcpay-liquid',
        address: 'lq1destination',
        networkFee: const NetworkFee.relative(0.1),
        drain: true,
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
      () => walletRepository.getWallets(
        environment: Environment.mainnet,
        onlyDefaults: true,
        onlyBitcoin: true,
        onlyLiquid: false,
      ),
    ).thenAnswer(
      (_) async => [
        _wallet(
          id: 'default-bitcoin',
          network: Network.bitcoinMainnet,
          isDefault: true,
        ),
      ],
    );
    when(
      () => walletAddressRepository.getLastRevealedReceiveAddress(
        walletId: 'default-bitcoin',
      ),
    ).thenAnswer((_) async => _address('default-bitcoin', 'bc1destination'));
    when(() => getNetworkFees.execute(isLiquid: false)).thenAnswer(
      (_) async => const FeeOptions(
        fastest: NetworkFee.relative(10),
        economic: NetworkFee.relative(2),
        slow: NetworkFee.relative(1),
      ),
    );
    when(
      () => bitcoinWalletRepository.buildPsbt(
        walletId: 'btcpay-bitcoin',
        address: 'bc1destination',
        networkFee: const NetworkFee.relative(2),
        drain: true,
      ),
    ).thenAnswer((_) async => 'psbt');
    when(
      () => bitcoinWalletRepository.getTxFeeAmount(psbt: 'psbt'),
    ).thenAnswer((_) async => 100);

    final txid = await usecase.execute(source);

    expect(txid, isNull);
    verifyNever(
      () => bitcoinWalletRepository.signPsbt(
        any(),
        walletId: any(named: 'walletId'),
      ),
    );
    verifyNever(
      () => broadcastBitcoin.execute(any(), isPsbt: any(named: 'isPsbt')),
    );
    verifyNever(() => labelsFacade.store(any()));
  });

  test('does not sweep wallets without auto-sweep enabled', () async {
    final txid = await usecase.execute(
      _wallet(id: 'manual', network: Network.liquidMainnet),
    );

    expect(txid, isNull);
    verifyNever(
      () => walletRepository.getWallets(
        environment: any(named: 'environment'),
        onlyDefaults: any(named: 'onlyDefaults'),
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

WalletAddress _address(String walletId, String address) {
  return WalletAddress(
    walletId: walletId,
    index: 1,
    address: address,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}
