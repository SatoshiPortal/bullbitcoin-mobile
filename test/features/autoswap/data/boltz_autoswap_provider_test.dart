import 'package:primitives/primitives.dart'
    show BitcoinUnit, Err, Ok, Sats, ScriptType;
import 'package:primitives/primitives.dart' show SignerEntity;
import 'package:fees/fees.dart';
import 'package:preferences/preferences.dart';
import 'package:swaps/swaps.dart' hide Environment;
import 'package:swaps/swaps.dart' as swaps show Environment;
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/address_view/domain/wallet_address.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/autoswap/data/boltz_autoswap_provider.dart';
import 'package:labels/labels.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spend/spend.dart';
import 'package:spend/testing.dart';

class _MockGetSwapLimitsAndFees extends Mock
    implements GetSwapLimitsAndFeesUsecase {}

class _MockCreateLiquidToBitcoinSwap extends Mock
    implements CreateLiquidToBitcoinSwapUsecase {}

class _MockRecordSwapLockup extends Mock implements RecordSwapLockupUsecase {}

class _MockRecordPendingLockup extends Mock
    implements RecordPendingSwapLockupUsecase {}

class _MockDropPendingLockup extends Mock
    implements DropPendingSwapLockupUsecase {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockPreferences extends Mock implements Preferences {}

class _MockSpend extends Mock implements Spend {}

class _MockGetReceiveAddress extends Mock implements GetReceiveAddressUsecase {}

class _MockLabels extends Mock implements Labels {}

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

Matcher _toWallet(String walletId) =>
    isA<ToWallet>().having((d) => d.walletId, 'walletId', walletId);

void main() {
  late _MockGetSwapLimitsAndFees getLimitsAndFees;
  late _MockCreateLiquidToBitcoinSwap createLiquidToBitcoinSwap;
  late _MockRecordSwapLockup recordLockup;
  late _MockRecordPendingLockup recordPendingLockup;
  late _MockDropPendingLockup dropPendingLockup;
  late _MockWalletRepository walletRepository;
  late _MockPreferences settingsRepository;
  late _MockSpend spend;
  late _MockGetReceiveAddress getReceiveAddress;
  late _MockLabels labelsFacade;
  late BoltzAutoswapProvider provider;
  final prepared = SpendFixtures.preparedLiquid(
    unsignedPset: 'pset',
    fee: Sats.fromInt(500),
    amountSent: Sats.fromInt(2_499_500),
  );
  final signed = SpendFixtures.signedLiquid('signed-pset');

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
    registerFallbackValue(prepared);
    registerFallbackValue(signed);
    registerFallbackValue(SwapType.liquidToBitcoin);
    registerFallbackValue(const ToWallet(''));
    registerFallbackValue(
      NewLabel.tx(transactionId: '', origin: '', label: ''),
    );
  });

  setUp(() {
    getLimitsAndFees = _MockGetSwapLimitsAndFees();
    createLiquidToBitcoinSwap = _MockCreateLiquidToBitcoinSwap();
    recordLockup = _MockRecordSwapLockup();
    recordPendingLockup = _MockRecordPendingLockup();
    dropPendingLockup = _MockDropPendingLockup();
    when(
      () => recordPendingLockup.execute(
        swapId: any(named: 'swapId'),
        signedTx: any(named: 'signedTx'),
      ),
    ).thenAnswer(
      (_) async => Ok(
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
        ),
      ),
    );
    when(() => dropPendingLockup.execute(any()))
        .thenAnswer((_) async => const Ok(null));
    walletRepository = _MockWalletRepository();
    settingsRepository = _MockPreferences();
    spend = _MockSpend();
    getReceiveAddress = _MockGetReceiveAddress();
    labelsFacade = _MockLabels();
    provider = BoltzAutoswapProvider(
      getLimitsAndFees,
      createLiquidToBitcoinSwap,
      recordLockup,
      recordPendingLockup,
      dropPendingLockup,
      walletRepository,
      settingsRepository,
      spend,
      getReceiveAddress,
      labelsFacade,
    );

    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.testnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      ),
    );
    when(() => walletRepository.getWallets(environment: Environment.testnet))
        .thenAnswer(
          (_) async => Ok([_wallet(liquid: true), _wallet(liquid: false)]),
        );
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
      () => spend.prepareLiquid(
        walletId: 'liquid-wallet',
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        feeRate: any(named: 'feeRate'),
      ),
    ).thenAnswer((_) async => Ok(prepared));
    when(() => getLimitsAndFees.execute(SwapType.liquidToBitcoin)).thenAnswer(
      (_) async => const Ok((
        SwapLimits(min: 3_570, max: 10_000_000),
        SwapFees(boltzPercent: 0.25, claimFee: 389),
      )),
    );
    when(
      () => createLiquidToBitcoinSwap.execute(
        sendWalletId: 'liquid-wallet',
        amountSat: 2_499_500,
        destination: any(
          named: 'destination',
          that: _toWallet('bitcoin-wallet'),
        ),
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
        ) as ChainSwap,
      ),
    );
    when(() => spend.signLiquid(prepared: prepared))
        .thenAnswer((_) async => Ok(signed));
    when(() => spend.broadcastLiquid(signed)).thenAnswer(
      (_) async => const Ok((txid: 'txid', guarded: false, durable: false)),
    );
    when(
      () => recordLockup.execute(
        swapId: 'swap-id',
        txid: 'txid',
        lockupFeeSat: 500,
      ),
    ).thenAnswer((_) async => const Err(SwapsUnexpectedFailure()));
    when(() => labelsFacade.store(any()))
        .thenAnswer((_) async => const Err(LabelUnexpectedFailure()));
  });

  test('stops before signing when Liquid build 1 returns Err', () async {
    var builds = 0;
    when(
      () => spend.prepareLiquid(
        walletId: 'liquid-wallet',
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        feeRate: any(named: 'feeRate'),
      ),
    ).thenAnswer(
      (_) async => builds++ == 0
          ? const Err(SpendNoSpendableInputsFailure())
          : Ok(prepared),
    );
    final result = await provider.execute(settings);
    expect(result, isA<Err<String, AutoswapFailure>>());
    expect(builds, 1);
    verifyNever(() => spend.signLiquid(prepared: any(named: 'prepared')));
    verifyNever(() => spend.broadcastLiquid(any()));
  });

  test('stops before signing when Liquid build 2 returns Err', () async {
    var builds = 0;
    when(
      () => spend.prepareLiquid(
        walletId: 'liquid-wallet',
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        feeRate: any(named: 'feeRate'),
      ),
    ).thenAnswer(
      (_) async => builds++ == 1
          ? const Err(SpendNoSpendableInputsFailure())
          : Ok(prepared),
    );
    final result = await provider.execute(settings);
    expect(result, isA<Err<String, AutoswapFailure>>());
    expect(builds, 2);
    verifyNever(() => spend.signLiquid(prepared: any(named: 'prepared')));
    verifyNever(() => spend.broadcastLiquid(any()));
  });

  test(
    'creates the chain swap, broadcasts the lockup and records it',
    () async {
      final result = await provider.execute(settings);

      expect(result, isA<Ok<String, AutoswapFailure>>());
      expect((result as Ok<String, AutoswapFailure>).value, 'swap-id');
      verify(
        () => createLiquidToBitcoinSwap.execute(
          sendWalletId: 'liquid-wallet',
          amountSat: 2_499_500,
          destination: any(
            named: 'destination',
            that: _toWallet('bitcoin-wallet'),
          ),
        ),
      ).called(1);
      verify(() => spend.broadcastLiquid(signed)).called(1);
      verify(
        () => recordLockup.execute(
          swapId: 'swap-id',
          txid: 'txid',
          lockupFeeSat: 500,
        ),
      ).called(1);
    },
  );

  test('stores the signed lockup before broadcasting it', () async {
    await provider.execute(settings);

    verifyInOrder([
      () => recordPendingLockup.execute(
        swapId: 'swap-id',
        signedTx: 'signed-pset',
      ),
      () => spend.broadcastLiquid(signed),
    ]);
  });

  test('broadcasts nothing when the lockup cannot be stored', () async {
    when(
      () => recordPendingLockup.execute(
        swapId: any(named: 'swapId'),
        signedTx: any(named: 'signedTx'),
      ),
    ).thenAnswer((_) async => const Err(SwapsUnexpectedFailure()));

    final result = await provider.execute(settings);

    expect((result as Err).failure, isA<AutoswapExecutionFailure>());
    verifyNever(() => spend.broadcastLiquid(any()));
  });

  test('keeps the pending lockup after an uncertain broadcast', () async {
    when(
      () => spend.broadcastLiquid(signed),
    ).thenAnswer((_) async => const Err(SpendBroadcastOutcomeUnknownFailure()));
    expect(
      await provider.execute(settings),
      isA<Err<String, AutoswapFailure>>(),
    );
    verifyNever(() => dropPendingLockup.execute(any()));
    verifyNever(
      () => recordLockup.execute(
        swapId: any(named: 'swapId'),
        txid: any(named: 'txid'),
        lockupFeeSat: any(named: 'lockupFeeSat'),
      ),
    );
  });

  test('drops the pending lockup after a definitive rejection', () async {
    when(() => spend.broadcastLiquid(signed)).thenAnswer(
      (_) async => const Err(
        SpendBroadcastRejectedFailure(SpendBroadcastRejection.nodeRejected),
      ),
    );
    expect(
      await provider.execute(settings),
      isA<Err<String, AutoswapFailure>>(),
    );
    verify(() => dropPendingLockup.execute('swap-id')).called(1);
  });

  test('Boltz unreachable is reported before anything is created', () async {
    when(
      () => getLimitsAndFees.execute(SwapType.liquidToBitcoin),
    ).thenAnswer((_) async => const Err(SwapsBoltzUnavailableFailure('418')));

    final result = await provider.execute(settings);

    expect((result as Err).failure, isA<AutoswapBoltzUnavailableFailure>());
    verifyNever(
      () => createLiquidToBitcoinSwap.execute(
        sendWalletId: any(named: 'sendWalletId'),
        amountSat: any(named: 'amountSat'),
        destination: any(named: 'destination'),
      ),
    );
  });

  test(
    'a refused creation maps to the failures the route can fall back on',
    () async {
      when(
        () => createLiquidToBitcoinSwap.execute(
          sendWalletId: any(named: 'sendWalletId'),
          amountSat: any(named: 'amountSat'),
          destination: any(named: 'destination'),
        ),
      ).thenAnswer(
        (_) async => const Err(
          SwapsAmountOutOfLimitsFailure(minSat: 3_570, maxSat: 2_000_000),
        ),
      );

      final result = await provider.execute(settings);

      expect((result as Err).failure, isA<AutoswapAmountOutOfBoundsFailure>());
      verifyNever(() => spend.broadcastLiquid(any()));
    },
  );
}
