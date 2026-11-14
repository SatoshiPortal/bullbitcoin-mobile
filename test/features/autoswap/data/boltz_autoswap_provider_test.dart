import 'package:bb_mobile/features/send/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, Err, Ok;
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:swaps/swaps.dart' hide Environment;
import 'package:swaps/swaps.dart' as swaps show Environment;
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/features/wallet/data/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/autoswap/data/boltz_autoswap_provider.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSwaps extends Mock implements GetSwapsUsecase {}

class _MockGetSwapLimitsAndFees extends Mock
    implements GetSwapLimitsAndFeesUsecase {}

class _MockCreateChainSwap extends Mock implements CreateChainSwapUsecase {}

class _MockRecordSwapLockup extends Mock implements RecordSwapLockupUsecase {}

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
  late _MockGetSwaps getSwaps;
  late _MockGetSwapLimitsAndFees getLimitsAndFees;
  late _MockCreateChainSwap createChainSwap;
  late _MockRecordSwapLockup recordLockup;
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
    registerFallbackValue(SwapType.liquidToBitcoin);
    registerFallbackValue(
      NewLabel.tx(transactionId: '', origin: '', label: ''),
    );
  });

  setUp(() {
    getSwaps = _MockGetSwaps();
    getLimitsAndFees = _MockGetSwapLimitsAndFees();
    createChainSwap = _MockCreateChainSwap();
    recordLockup = _MockRecordSwapLockup();
    walletRepository = _MockWalletRepository();
    settingsRepository = _MockSettingsRepository();
    liquidWalletRepository = _MockLiquidWalletRepository();
    getReceiveAddress = _MockGetReceiveAddress();
    broadcastLiquid = _MockBroadcastLiquid();
    labelsFacade = _MockLabelsFacade();
    provider = BoltzAutoswapProvider(
      getSwaps,
      getLimitsAndFees,
      createChainSwap,
      recordLockup,
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
    ).thenAnswer(
      (_) async => Ok([_wallet(liquid: true), _wallet(liquid: false)]),
    );
    when(
      () => getSwaps.execute(walletId: 'liquid-wallet'),
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
    ).thenAnswer((_) async => const Ok('pset'));
    when(
      () => liquidWalletRepository.getPsetSizeAndAbsoluteFees(pset: 'pset'),
    ).thenAnswer((_) async => (100, 500));
    when(() => getLimitsAndFees.execute(SwapType.liquidToBitcoin)).thenAnswer(
      (_) async => const Ok((
        SwapLimits(min: 3_570, max: 10_000_000),
        SwapFees(boltzPercent: 0.25, claimFee: 389),
      )),
    );
    when(
      () => createChainSwap.execute(
        sendWalletId: 'liquid-wallet',
        amountSat: 2_499_500,
        fromLiquid: true,
        receiveWalletId: 'bitcoin-wallet',
      ),
    ).thenAnswer(
      (_) async => Ok(
        Swap.chain(
              id: 'swap-id',
              keyIndex: 0,
              type: SwapType.liquidToBitcoin,
              status: SwapStatus.pending,
              environment: swaps.Environment.testnet,
              creationTime: DateTime.utc(2026),
              sendWalletId: 'liquid-wallet',
              paymentAddress: 'tlq1payin',
              paymentAmount: 2_499_500,
              receiveWalletId: 'bitcoin-wallet',
            )
            as ChainSwap,
      ),
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
      () => recordLockup.execute(
        swapId: 'swap-id',
        txid: 'txid',
        lockupFeeSat: 500,
      ),
    ).thenAnswer((_) async => const Err(SwapsUnexpectedFailure()));
    when(
      () => labelsFacade.store(any()),
    ).thenAnswer((_) async => const Err(LabelUnexpectedFailure()));
  });

  test('stops before signing when Liquid build 1 returns Err', () async {
    var builds = 0;
    when(
      () => liquidWalletRepository.buildPset(
        walletId: 'liquid-wallet',
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        feeRate: any(named: 'feeRate'),
      ),
    ).thenAnswer(
      (_) async => builds++ == 0
          ? const Err(WalletNoSpendableInputsFailure())
          : const Ok('pset'),
    );
    final result = await provider.execute(settings);
    expect(result, isA<Err<String, AutoswapFailure>>());
    expect(builds, 1);
    verifyNever(
      () => liquidWalletRepository.signPset(
        walletId: any(named: 'walletId'),
        pset: any(named: 'pset'),
      ),
    );
    verifyZeroInteractions(broadcastLiquid);
  });

  test('stops before signing when Liquid build 2 returns Err', () async {
    var builds = 0;
    when(
      () => liquidWalletRepository.buildPset(
        walletId: 'liquid-wallet',
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        feeRate: any(named: 'feeRate'),
      ),
    ).thenAnswer(
      (_) async => builds++ == 1
          ? const Err(WalletNoSpendableInputsFailure())
          : const Ok('pset'),
    );
    final result = await provider.execute(settings);
    expect(result, isA<Err<String, AutoswapFailure>>());
    expect(builds, 2);
    verifyNever(
      () => liquidWalletRepository.signPset(
        walletId: any(named: 'walletId'),
        pset: any(named: 'pset'),
      ),
    );
    verifyZeroInteractions(broadcastLiquid);
  });

  test(
    'creates the chain swap, broadcasts the lockup and records it',
    () async {
      final result = await provider.execute(settings);

      expect(result, isA<Ok<String, AutoswapFailure>>());
      expect((result as Ok<String, AutoswapFailure>).value, 'swap-id');
      verify(
        () => createChainSwap.execute(
          sendWalletId: 'liquid-wallet',
          amountSat: 2_499_500,
          fromLiquid: true,
          receiveWalletId: 'bitcoin-wallet',
        ),
      ).called(1);
      verify(
        () => broadcastLiquid.execute('signed-pset', isTestnet: true),
      ).called(1);
      verify(
        () => recordLockup.execute(
          swapId: 'swap-id',
          txid: 'txid',
          lockupFeeSat: 500,
        ),
      ).called(1);
    },
  );

  test('Boltz unreachable is reported before anything is created', () async {
    when(
      () => getLimitsAndFees.execute(SwapType.liquidToBitcoin),
    ).thenAnswer((_) async => const Err(SwapsBoltzUnavailableFailure('418')));

    final result = await provider.execute(settings);

    expect((result as Err).failure, isA<AutoswapBoltzUnavailableFailure>());
    verifyNever(
      () => createChainSwap.execute(
        sendWalletId: any(named: 'sendWalletId'),
        amountSat: any(named: 'amountSat'),
        fromLiquid: any(named: 'fromLiquid'),
        receiveWalletId: any(named: 'receiveWalletId'),
      ),
    );
  });

  test(
    'a refused creation maps to the failures the route can fall back on',
    () async {
      when(
        () => createChainSwap.execute(
          sendWalletId: any(named: 'sendWalletId'),
          amountSat: any(named: 'amountSat'),
          fromLiquid: any(named: 'fromLiquid'),
          receiveWalletId: any(named: 'receiveWalletId'),
        ),
      ).thenAnswer(
        (_) async => const Err(
          SwapsAmountOutOfLimitsFailure(minSat: 3_570, maxSat: 2_000_000),
        ),
      );

      final result = await provider.execute(settings);

      expect((result as Err).failure, isA<AutoswapAmountOutOfBoundsFailure>());
      verifyNever(
        () =>
            broadcastLiquid.execute(any(), isTestnet: any(named: 'isTestnet')),
      );
    },
  );

  test('an unfunded swap in flight blocks a second one', () async {
    when(() => getSwaps.execute(walletId: 'liquid-wallet')).thenAnswer(
      (_) async => [
        Swap.chain(
          id: 'pending',
          keyIndex: 0,
          type: SwapType.liquidToBitcoin,
          status: SwapStatus.pending,
          environment: swaps.Environment.testnet,
          creationTime: DateTime.utc(2026),
          sendWalletId: 'liquid-wallet',
          paymentAddress: 'tlq1payin',
          paymentAmount: 1_000,
          receiveWalletId: 'bitcoin-wallet',
        ),
      ],
    );

    final result = await provider.execute(settings);

    expect((result as Err).failure, isA<AutoswapPendingFailure>());
    verifyNever(() => getLimitsAndFees.execute(any()));
  });
}
