import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/autoswap/data/boltz_autoswap_provider.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBoltzSwapRepository extends Mock implements BoltzSwapRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockLiquidWalletRepository extends Mock
    implements LiquidWalletRepository {}

class _MockGetReceiveAddress extends Mock implements GetReceiveAddressUsecase {}

class _MockBroadcastLiquid extends Mock
    implements BroadcastLiquidTransactionUsecase {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

Wallet _wallet({required bool liquid}) => Wallet(
  origin: liquid ? 'liquid-wallet' : 'bitcoin-wallet',
  network: liquid ? Network.liquidTestnet : Network.bitcoinTestnet,
  isDefault: true,
  xpubFingerprint: 'fingerprint',
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: 'external',
  internalPublicDescriptor: 'internal',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(liquid ? 3_000_000 : 0),
);

void main() {
  late _MockBoltzSwapRepository swapRepository;
  late _MockWalletRepository walletRepository;
  late _MockSettingsRepository settingsRepository;
  late _MockLiquidWalletRepository liquidWalletRepository;
  late _MockGetReceiveAddress getReceiveAddress;
  late _MockBroadcastLiquid broadcastLiquid;
  late _MockLabelsFacade labelsFacade;
  late BoltzAutoswapProvider provider;

  const settings = AutoSwap(
    enabled: true,
    showWarning: false,
    balanceThresholdSats: 500_000,
    triggerBalanceSats: 1_000_000,
    feeThresholdPercent: 3,
    recipientWalletId: 'bitcoin-wallet',
  );

  setUpAll(() {
    registerFallbackValue(const RelativeFee(25));
    registerFallbackValue(
      NewLabel.tx(transactionId: '', origin: '', label: ''),
    );
  });

  setUp(() {
    swapRepository = _MockBoltzSwapRepository();
    walletRepository = _MockWalletRepository();
    settingsRepository = _MockSettingsRepository();
    liquidWalletRepository = _MockLiquidWalletRepository();
    getReceiveAddress = _MockGetReceiveAddress();
    broadcastLiquid = _MockBroadcastLiquid();
    labelsFacade = _MockLabelsFacade();
    provider = BoltzAutoswapProvider(
      swapRepository,
      walletRepository,
      settingsRepository,
      liquidWalletRepository,
      getReceiveAddress,
      broadcastLiquid,
      labelsFacade,
    );

    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    when(
      () => walletRepository.getWallets(environment: Environment.testnet),
    ).thenAnswer((_) async => [_wallet(liquid: true), _wallet(liquid: false)]);
    when(
      () => swapRepository.getOngoingSwaps(walletId: 'liquid-wallet'),
    ).thenAnswer((_) async => []);
    when(() => getReceiveAddress.execute(walletId: 'liquid-wallet')).thenAnswer(
      (_) async => WalletAddress(
        walletId: 'liquid-wallet',
        index: 0,
        address: 'tlq1fallback',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    when(
      () => liquidWalletRepository.buildPset(
        walletId: 'liquid-wallet',
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        feeRate: any(named: 'feeRate'),
      ),
    ).thenAnswer((_) async => 'pset');
    when(
      () => liquidWalletRepository.getPsetSizeAndAbsoluteFees(pset: 'pset'),
    ).thenAnswer((_) async => (100, 500));
    when(
      () => swapRepository.getSwapLimitsAndFees(SwapType.liquidToBitcoin),
    ).thenAnswer(
      (_) async => (
        const SwapLimits(min: 3_570, max: 10_000_000),
        const SwapFees(boltzPercent: 0.25, claimFee: 389),
      ),
    );
    when(
      () => swapRepository.createLiquidToBitcoinSwap(
        sendWalletId: 'liquid-wallet',
        amountSat: 2_499_500,
        btcElectrumUrl: ApiServiceConstants.publicElectrumTestUrl,
        lbtcElectrumUrl: ApiServiceConstants.publicliquidElectrumTestUrlPath,
        receiveWalletId: 'bitcoin-wallet',
      ),
    ).thenAnswer(
      (_) async =>
          Swap.chain(
                id: 'swap-id',
                keyIndex: 0,
                type: SwapType.liquidToBitcoin,
                status: SwapStatus.pending,
                environment: Environment.testnet,
                creationTime: DateTime.utc(2026),
                sendWalletId: 'liquid-wallet',
                paymentAddress: 'tlq1payin',
                paymentAmount: 2_499_500,
                receiveWalletId: 'bitcoin-wallet',
              )
              as ChainSwap,
    );
    when(
      () => liquidWalletRepository.getAmountSentToAddress(
        pset: 'pset',
        address: 'tlq1payin',
        walletId: 'liquid-wallet',
      ),
    ).thenAnswer((_) async => 2_499_500);
    when(
      () => liquidWalletRepository.signPset(
        walletId: 'liquid-wallet',
        pset: 'pset',
      ),
    ).thenAnswer((_) async => 'signed-pset');
    when(
      () => broadcastLiquid.execute('signed-pset', isTestnet: true),
    ).thenAnswer((_) async => 'txid');
    when(
      () => swapRepository.updatePaidSendSwap(
        swapId: 'swap-id',
        txid: 'txid',
        absoluteFees: 500,
      ),
    ).thenAnswer((_) async {});
    when(
      () => labelsFacade.store(any()),
    ).thenAnswer((_) async => const Err(LabelUnexpectedFailure()));
  });

  test('uses testnet services and broadcasts the payin on testnet', () async {
    final result = await provider.execute(settings);

    expect(result, isA<Ok<String, AutoswapFailure>>());
    expect((result as Ok<String, AutoswapFailure>).value, 'swap-id');
    verify(
      () => walletRepository.getWallets(environment: Environment.testnet),
    ).called(1);
    verify(
      () => swapRepository.createLiquidToBitcoinSwap(
        sendWalletId: 'liquid-wallet',
        amountSat: 2_499_500,
        btcElectrumUrl: ApiServiceConstants.publicElectrumTestUrl,
        lbtcElectrumUrl: ApiServiceConstants.publicliquidElectrumTestUrlPath,
        receiveWalletId: 'bitcoin-wallet',
      ),
    ).called(1);
    verify(
      () => broadcastLiquid.execute('signed-pset', isTestnet: true),
    ).called(1);
  });
}
