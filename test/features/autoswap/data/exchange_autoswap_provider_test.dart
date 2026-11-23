import 'package:spend/spend.dart';
import 'package:spend/testing.dart';
import 'package:primitives/primitives.dart' show LiquidNetwork, Sats;
import 'package:primitives/primitives.dart' show SignerEntity;
import 'package:fees/fees.dart';
import 'package:preferences/preferences.dart';
import 'package:swaps/swaps.dart' hide Environment;
import 'package:primitives/primitives.dart'
    show BitcoinUnit, Err, Ok, Result, ScriptType;
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:address_view/address_view.dart';
import 'package:bb_mobile/features/autoswap/data/exchange_autoswap_provider.dart';
import 'package:labels/labels.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSpend extends Mock implements Spend {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockPreferences extends Mock implements Preferences {}

class _MockGetReceiveAddress extends Mock implements AddressView {}

class _MockSwapFacade extends Mock implements SwapFacade {}

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
  balanceSat: BigInt.from(liquid ? 3000000 : 0),
);

OrderSwapRecord _record({
  OrderSwapLocalStatus status = OrderSwapLocalStatus.awaitingUserConfirmation,
  String? signedTransaction,
}) {
  final order = OrderSwap(
    orderId: 'order-id',
    orderNumber: 42,
    inNetwork: OrderSwapNetwork.liquid,
    outNetwork: OrderSwapNetwork.bitcoin,
    payinAmountSat: BigInt.from(2499500),
    payoutAmountSat: BigInt.from(2479500),
    payinCurrency: 'LBTC',
    payoutCurrency: 'BTC',
    payinMethod: 'Liquid',
    payoutMethod: 'Bitcoin',
    orderType: 'Swap',
    orderStatus: 'Pending',
    payinStatus: 'Pending',
    payoutStatus: 'Pending',
    messageCode: '',
    bitcoinAddress: 'tb1qdestination000000000000000000000000000000',
    liquidAddress: 'tlq1payin00000000000000000000000000000000000',
    createdAt: DateTime.utc(2026),
    confirmationDeadline: DateTime.utc(2026, 1, 1, 1),
  );
  return OrderSwapRecord(
    localId: 'local-id',
    purpose: OrderSwapPurpose.autoswap,
    environment: OrderSwapEnvironment.testnet,
    inNetwork: OrderSwapNetwork.liquid,
    outNetwork: OrderSwapNetwork.bitcoin,
    isInAmountFixed: true,
    requestedAmountSat: order.payinAmountSat,
    quotedCounterpartAmountSat: order.payoutAmountSat,
    sourceWalletId: 'liquid-wallet',
    destinationWalletId: 'bitcoin-wallet',
    destination: order.bitcoinAddress!,
    fallback: 'tlq1fallback000000000000000000000000000000000',
    order: order,
    signedPayinTransaction: signedTransaction,
    payinIsPsbt: signedTransaction == null ? null : false,
    createdAt: DateTime.utc(2026),
    localStatus: status,
  );
}

void main() {
  late _MockWalletRepository walletRepository;
  late _MockPreferences settingsRepository;
  late _MockSpend spend;
  late _MockGetReceiveAddress getReceiveAddress;
  late _MockSwapFacade swapFacade;
  late _MockLabels labelsFacade;
  late ExchangeAutoswapProvider provider;
  late List<Duration> delays;

  const settings = AutoSwap(
    enabled: true,
    showWarning: false,
    balanceThresholdSats: 500000,
    triggerBalanceSats: 1000000,
    feeThresholdPercent: 3,
    recipientWalletId: 'bitcoin-wallet',
  );

  final preparedPset = SpendFixtures.preparedLiquid(
    unsignedPset: 'pset',
    fee: Sats.fromInt(500),
    amountSent: Sats.fromInt(2499500),
  );
  final signedPset = SpendFixtures.signedLiquid('signed-pset');

  Future<Result<SpendBroadcastReceipt, SpendFailure>> resume() =>
      spend.resumeLiquidPayin(
        signedPset: 'signed-pset',
        walletId: 'liquid-wallet',
        network: LiquidNetwork.testnet,
        address: _record().order!.payinAddress,
        amount: Sats.fromInt(2499500),
      );

  setUpAll(() {
    registerFallbackValue(preparedPset);
    registerFallbackValue(signedPset);
    registerFallbackValue(Sats.zero);

    registerFallbackValue(const RelativeFee(25));
    registerFallbackValue(BigInt.zero);
    registerFallbackValue(OrderSwapEnvironment.testnet);
    registerFallbackValue(OrderSwapNetwork.liquid);
    registerFallbackValue(
      NewLabel.tx(transactionId: '', origin: '', label: ''),
    );
  });

  setUp(() {
    walletRepository = _MockWalletRepository();
    settingsRepository = _MockPreferences();
    spend = _MockSpend();
    getReceiveAddress = _MockGetReceiveAddress();
    swapFacade = _MockSwapFacade();
    labelsFacade = _MockLabels();
    delays = [];
    provider = ExchangeAutoswapProvider(
      walletRepository,
      settingsRepository,
      spend,
      getReceiveAddress,
      swapFacade,
      labelsFacade,
      delay: (duration) async => delays.add(duration),
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
    when(() => swapFacade.getPendingOrders())
        .thenAnswer((_) async => const Ok([]));
    when(
      () => getReceiveAddress.receiveAddress(walletId: any(named: 'walletId')),
    ).thenAnswer((invocation) async {
      final walletId = invocation.namedArguments[#walletId] as String;
      return Ok(
        WalletAddress(
          walletId: walletId,
          address: walletId == 'bitcoin-wallet'
              ? 'tb1qdestination000000000000000000000000000000'
              : 'tlq1fallback000000000000000000000000000000000',
          index: 0,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
    });
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
          : Ok(preparedPset),
    );
    final result = await provider.execute(settings);
    expect(result, isA<Err<String, AutoswapFailure>>());
    expect(builds, 1);
    verifyNever(() => spend.signLiquid(prepared: any(named: 'prepared')));
    verifyNever(() => spend.broadcastLiquid(any()));
  });

  test(
    'does not sign or broadcast a resumed order whose build returns Err',
    () async {
      when(() => swapFacade.getPendingOrders())
          .thenAnswer((_) async => Ok([_record()]));
      when(
        () => spend.prepareLiquid(
          walletId: 'liquid-wallet',
          address: any(named: 'address'),
          amountSat: any(named: 'amountSat'),
          feeRate: any(named: 'feeRate'),
        ),
      ).thenAnswer((_) async => const Err(SpendBuildRefusedFailure()));
      final result = await provider.execute(settings);
      expect(
        (result as Err<String, AutoswapFailure>).failure,
        isA<AutoswapExecutionFailure>(),
      );
      verify(
        () => spend.prepareLiquid(
          walletId: 'liquid-wallet',
          address: any(named: 'address'),
          amountSat: any(named: 'amountSat'),
          feeRate: any(named: 'feeRate'),
        ),
      ).called(1);
      verifyNever(() => spend.signLiquid(prepared: any(named: 'prepared')));
      verifyNever(() => spend.broadcastLiquid(any()));
    },
  );

  test('persists the signed payin before broadcasting it', () async {
    final record = _record();
    final prepared = _record(
      status: OrderSwapLocalStatus.readyToBroadcast,
      signedTransaction: 'signed-pset',
    );
    final broadcasting = _record(
      status: OrderSwapLocalStatus.broadcastUnknown,
      signedTransaction: 'signed-pset',
    );
    when(
      () => spend.prepareLiquid(
        walletId: 'liquid-wallet',
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        feeRate: any(named: 'feeRate'),
      ),
    ).thenAnswer((_) async => Ok(preparedPset));
    when(
      () => swapFacade.getQuote(
        environment: OrderSwapEnvironment.testnet,
        amountSat: BigInt.from(2499500),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.bitcoin,
      ),
    ).thenAnswer(
      (_) async => Ok(
        OrderSwapQuote(
          inAmountSat: BigInt.from(2499500),
          outAmountSat: BigInt.from(2479500),
          inNetwork: OrderSwapNetwork.liquid,
          outNetwork: OrderSwapNetwork.bitcoin,
          inCurrency: 'LBTC',
          outCurrency: 'BTC',
          feeBasisPoints: 80,
          warnings: const [],
        ),
      ),
    );
    when(
      () => swapFacade.createOrder(
        amountSat: any(named: 'amountSat'),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.bitcoin,
        destinationAddress: any(named: 'destinationAddress'),
        fallbackAddress: any(named: 'fallbackAddress'),
        purpose: OrderSwapPurpose.autoswap,
        environment: OrderSwapEnvironment.testnet,
        sourceWalletId: 'liquid-wallet',
        destinationWalletId: 'bitcoin-wallet',
        note: LabelSystem.autoSwap.label,
        quotedCounterpartAmountSat: any(named: 'quotedCounterpartAmountSat'),
      ),
    ).thenAnswer((_) async => Ok(record));
    when(() => spend.signLiquid(prepared: any(named: 'prepared')))
        .thenAnswer((_) async => Ok(signedPset));
    when(
      () => swapFacade.savePreparedPayin(
        localId: 'local-id',
        signedTransaction: 'signed-pset',
        isPsbt: false,
      ),
    ).thenAnswer((_) async => Ok(prepared));
    when(() => swapFacade.markBroadcastUnknown('local-id'))
        .thenAnswer((_) async => Ok(broadcasting));
    when(() => spend.broadcastLiquid(signedPset)).thenAnswer(
      (_) async => const Ok((txid: 'txid', durable: false, guarded: false)),
    );
    when(
      () => swapFacade.markPayinBroadcast(
        localId: 'local-id',
        transactionId: 'txid',
      ),
    ).thenAnswer((_) async => Ok(broadcasting));
    when(() => labelsFacade.store(any())).thenAnswer(
      (_) async => Ok(
        Label.tx(
          id: 1,
          transactionId: 'txid',
          origin: 'liquid-wallet',
          label: LabelSystem.autoSwap.label,
        ),
      ),
    );

    final result = await provider.execute(settings);
    expect(result, isA<Ok<String, AutoswapFailure>>());
    expect((result as Ok<String, AutoswapFailure>).value, 'local-id');
    verifyInOrder([
      () => swapFacade.savePreparedPayin(
        localId: 'local-id',
        signedTransaction: 'signed-pset',
        isPsbt: false,
      ),
      () => swapFacade.markBroadcastUnknown('local-id'),
      () => spend.broadcastLiquid(signedPset),
      () => swapFacade.markPayinBroadcast(
        localId: 'local-id',
        transactionId: 'txid',
      ),
    ]);
  });

  test('resumes a prepared order without creating another one', () async {
    final prepared = _record(
      status: OrderSwapLocalStatus.readyToBroadcast,
      signedTransaction: 'signed-pset',
    );
    final broadcasting = _record(
      status: OrderSwapLocalStatus.broadcastUnknown,
      signedTransaction: 'signed-pset',
    );
    when(() => swapFacade.getPendingOrders())
        .thenAnswer((_) async => Ok([prepared]));
    when(() => swapFacade.markBroadcastUnknown('local-id'))
        .thenAnswer((_) async => Ok(broadcasting));
    when(() => resume()).thenAnswer(
      (_) async => const Ok((txid: 'txid', durable: false, guarded: false)),
    );
    when(
      () => swapFacade.markPayinBroadcast(
        localId: 'local-id',
        transactionId: 'txid',
      ),
    ).thenAnswer((_) async => Ok(broadcasting));
    when(() => labelsFacade.store(any())).thenAnswer(
      (_) async => Ok(
        Label.tx(
          id: 1,
          transactionId: 'txid',
          origin: 'liquid-wallet',
          label: LabelSystem.autoSwap.label,
        ),
      ),
    );

    expect(
      await provider.execute(settings),
      isA<Ok<String, AutoswapFailure>>(),
    );
    verifyNever(
      () => swapFacade.getQuote(
        environment: any(named: 'environment'),
        amountSat: any(named: 'amountSat'),
        isInAmountFixed: any(named: 'isInAmountFixed'),
        inNetwork: any(named: 'inNetwork'),
        outNetwork: any(named: 'outNetwork'),
      ),
    );
  });

  test('refreshes an uncertain broadcast before retrying it', () async {
    final uncertain = _record(
      status: OrderSwapLocalStatus.broadcastUnknown,
      signedTransaction: 'signed-pset',
    );
    final paid = OrderSwapRecord(
      localId: uncertain.localId,
      purpose: uncertain.purpose,
      environment: uncertain.environment,
      inNetwork: uncertain.inNetwork,
      outNetwork: uncertain.outNetwork,
      isInAmountFixed: uncertain.isInAmountFixed,
      requestedAmountSat: uncertain.requestedAmountSat,
      quotedCounterpartAmountSat: uncertain.quotedCounterpartAmountSat,
      sourceWalletId: uncertain.sourceWalletId,
      destinationWalletId: uncertain.destinationWalletId,
      destination: uncertain.destination,
      fallback: uncertain.fallback,
      order: uncertain.order,
      localPayinTransactionId: 'existing-txid',
      signedPayinTransaction: uncertain.signedPayinTransaction,
      payinIsPsbt: uncertain.payinIsPsbt,
      createdAt: uncertain.createdAt,
      localStatus: OrderSwapLocalStatus.payinBroadcast,
    );
    when(() => swapFacade.getPendingOrders())
        .thenAnswer((_) async => Ok([uncertain]));
    when(() => swapFacade.refreshOrder('local-id'))
        .thenAnswer((_) async => Ok(paid));

    final result = await provider.execute(settings);

    expect(result, isA<Ok<String, AutoswapFailure>>());
    verify(() => swapFacade.refreshOrder('local-id')).called(1);
    verifyNever(
      () => spend.resumeLiquidPayin(
        signedPset: any(named: 'signedPset'),
        walletId: any(named: 'walletId'),
        network: LiquidNetwork.testnet,
        address: any(named: 'address'),
        amount: any(named: 'amount'),
      ),
    );
  });

  test('rebroadcasts the persisted signed payin after a crash before broadcast '
      'was confirmed', () async {
    final uncertain = _record(
      status: OrderSwapLocalStatus.broadcastUnknown,
      signedTransaction: 'signed-pset',
    );
    when(() => swapFacade.getPendingOrders())
        .thenAnswer((_) async => Ok([uncertain]));
    when(() => swapFacade.refreshOrder('local-id'))
        .thenAnswer((_) async => Ok(uncertain));
    when(() => swapFacade.markBroadcastUnknown('local-id'))
        .thenAnswer((_) async => Ok(uncertain));
    when(() => resume()).thenAnswer(
      (_) async => const Ok((txid: 'txid', durable: false, guarded: false)),
    );
    when(
      () => swapFacade.markPayinBroadcast(
        localId: 'local-id',
        transactionId: 'txid',
      ),
    ).thenAnswer(
      (_) async => Ok(
        uncertain.withPayinState(
          status: OrderSwapLocalStatus.payinBroadcast,
          transactionId: 'txid',
        ),
      ),
    );
    when(() => labelsFacade.store(any())).thenAnswer(
      (_) async => Ok(
        Label.tx(
          id: 1,
          transactionId: 'txid',
          origin: 'liquid-wallet',
          label: LabelSystem.autoSwap.label,
        ),
      ),
    );

    final result = await provider.execute(settings);

    expect(result, isA<Ok<String, AutoswapFailure>>());
    expect((result as Ok<String, AutoswapFailure>).value, 'local-id');
    verify(() => swapFacade.refreshOrder('local-id')).called(1);
    verify(() => resume()).called(1);
    verify(
      () => swapFacade.markPayinBroadcast(
        localId: 'local-id',
        transactionId: 'txid',
      ),
    ).called(1);
  });

  test('never rebroadcasts once the payin has already been observed', () async {
    final uncertain = _record(
      status: OrderSwapLocalStatus.broadcastUnknown,
      signedTransaction: 'signed-pset',
    );
    final observed = uncertain.withPayinState(
      status: OrderSwapLocalStatus.payinBroadcast,
      transactionId: 'existing-txid',
    );
    when(() => swapFacade.getPendingOrders())
        .thenAnswer((_) async => Ok([uncertain]));
    when(() => swapFacade.refreshOrder('local-id'))
        .thenAnswer((_) async => Ok(observed));

    final result = await provider.execute(settings);

    expect(result, isA<Ok<String, AutoswapFailure>>());
    verify(() => swapFacade.refreshOrder('local-id')).called(1);
    verifyNever(
      () => spend.resumeLiquidPayin(
        signedPset: any(named: 'signedPset'),
        walletId: any(named: 'walletId'),
        network: LiquidNetwork.testnet,
        address: any(named: 'address'),
        amount: any(named: 'amount'),
      ),
    );
  });

  test('uncertain submission keeps the signed order pending', () async {
    final stored = _record(
      status: OrderSwapLocalStatus.readyToBroadcast,
      signedTransaction: 'signed-pset',
    );
    final pending = _record(
      status: OrderSwapLocalStatus.broadcastUnknown,
      signedTransaction: 'signed-pset',
    );
    when(() => swapFacade.getPendingOrders())
        .thenAnswer((_) async => Ok([stored]));
    when(() => swapFacade.markBroadcastUnknown('local-id'))
        .thenAnswer((_) async => Ok(pending));
    when(
      resume,
    ).thenAnswer((_) async => const Err(SpendBroadcastOutcomeUnknownFailure()));

    final result = await provider.execute(settings);

    expect(
      (result as Err<String, AutoswapFailure>).failure,
      isA<AutoswapPendingFailure>(),
    );
    verify(resume).called(1);
    verifyNever(
      () => swapFacade.markPayinBroadcast(
        localId: any(named: 'localId'),
        transactionId: any(named: 'transactionId'),
      ),
    );
  });

  test(
    'returns a typed failure when the persisted payin cannot be broadcast',
    () async {
      final uncertain = _record(
        status: OrderSwapLocalStatus.broadcastUnknown,
        signedTransaction: 'signed-pset',
      );
      when(() => swapFacade.getPendingOrders())
          .thenAnswer((_) async => Ok([uncertain]));
      when(() => swapFacade.refreshOrder('local-id'))
          .thenAnswer((_) async => Ok(uncertain));
      when(() => swapFacade.markBroadcastUnknown('local-id'))
          .thenAnswer((_) async => Ok(uncertain));
      when(() => resume()).thenAnswer(
        (_) async => const Err(
          SpendBroadcastRejectedFailure(SpendBroadcastRejection.nodeRejected),
        ),
      );

      final result = await provider.execute(settings);

      expect(result, isA<Err<String, AutoswapFailure>>());
      expect(
        (result as Err<String, AutoswapFailure>).failure,
        isA<AutoswapExecutionFailure>(),
      );
      verifyNever(
        () => swapFacade.markPayinBroadcast(
          localId: any(named: 'localId'),
          transactionId: any(named: 'transactionId'),
        ),
      );
    },
  );

  group('a rate-limited order creation', () {
    /// Stubs everything up to `createOrder` so each test only has to say what
    /// that call returns, in order.
    void stubUpToCreate(List<Result<OrderSwapRecord, SwapFailure>> creates) {
      when(
        () => spend.prepareLiquid(
          walletId: 'liquid-wallet',
          address: any(named: 'address'),
          amountSat: any(named: 'amountSat'),
          feeRate: any(named: 'feeRate'),
        ),
      ).thenAnswer((_) async => Ok(preparedPset));
      when(
        () => swapFacade.getQuote(
          environment: OrderSwapEnvironment.testnet,
          amountSat: any(named: 'amountSat'),
          isInAmountFixed: true,
          inNetwork: OrderSwapNetwork.liquid,
          outNetwork: OrderSwapNetwork.bitcoin,
        ),
      ).thenAnswer(
        (_) async => Ok(
          OrderSwapQuote(
            inAmountSat: BigInt.from(2499500),
            outAmountSat: BigInt.from(2479500),
            inNetwork: OrderSwapNetwork.liquid,
            outNetwork: OrderSwapNetwork.bitcoin,
            inCurrency: 'LBTC',
            outCurrency: 'BTC',
            feeBasisPoints: 80,
            warnings: const [],
          ),
        ),
      );
      final remaining = [...creates];
      when(
        () => swapFacade.createOrder(
          amountSat: any(named: 'amountSat'),
          isInAmountFixed: true,
          inNetwork: OrderSwapNetwork.liquid,
          outNetwork: OrderSwapNetwork.bitcoin,
          destinationAddress: any(named: 'destinationAddress'),
          fallbackAddress: any(named: 'fallbackAddress'),
          purpose: OrderSwapPurpose.autoswap,
          environment: OrderSwapEnvironment.testnet,
          sourceWalletId: 'liquid-wallet',
          destinationWalletId: 'bitcoin-wallet',
          note: LabelSystem.autoSwap.label,
          quotedCounterpartAmountSat: any(named: 'quotedCounterpartAmountSat'),
        ),
      ).thenAnswer((_) async => remaining.removeAt(0));
    }

    test('is retried once after the delay the server asks for', () async {
      stubUpToCreate([
        const Err(SwapRateLimitedFailure(retryAfter: Duration(seconds: 5))),
        const Err(SwapProviderFailure('second attempt')),
      ]);

      final result = await provider.execute(settings);

      // Waited exactly as long as the server asked, then tried again.
      expect(delays, [const Duration(seconds: 5)]);
      expect(
        (result as Err<String, AutoswapFailure>).failure,
        isA<AutoswapProviderFailure>(),
      );
      verify(
        () => swapFacade.createOrder(
          amountSat: any(named: 'amountSat'),
          isInAmountFixed: true,
          inNetwork: OrderSwapNetwork.liquid,
          outNetwork: OrderSwapNetwork.bitcoin,
          destinationAddress: any(named: 'destinationAddress'),
          fallbackAddress: any(named: 'fallbackAddress'),
          purpose: OrderSwapPurpose.autoswap,
          environment: OrderSwapEnvironment.testnet,
          sourceWalletId: 'liquid-wallet',
          destinationWalletId: 'bitcoin-wallet',
          note: LabelSystem.autoSwap.label,
          quotedCounterpartAmountSat: any(named: 'quotedCounterpartAmountSat'),
        ),
      ).called(2);
    });

    test('falls back to a short delay when none is supplied', () async {
      stubUpToCreate([
        const Err(SwapRateLimitedFailure()),
        const Err(SwapProviderFailure('second attempt')),
      ]);

      await provider.execute(settings);

      expect(delays, [const Duration(seconds: 5)]);
    });

    /// `Retry-After` is server-controlled and unbounded. Sleeping on a long
    /// one would park the watcher and stall its disposal, so the run gives up
    /// and lets the next wallet sync try again.
    test('a delay longer than the cap is not waited out', () async {
      stubUpToCreate([
        const Err(SwapRateLimitedFailure(retryAfter: Duration(minutes: 10))),
      ]);

      final result = await provider.execute(settings);

      expect(delays, isEmpty);
      expect(
        (result as Err<String, AutoswapFailure>).failure,
        isA<AutoswapProviderFailure>(),
      );
      verify(
        () => swapFacade.createOrder(
          amountSat: any(named: 'amountSat'),
          isInAmountFixed: true,
          inNetwork: OrderSwapNetwork.liquid,
          outNetwork: OrderSwapNetwork.bitcoin,
          destinationAddress: any(named: 'destinationAddress'),
          fallbackAddress: any(named: 'fallbackAddress'),
          purpose: OrderSwapPurpose.autoswap,
          environment: OrderSwapEnvironment.testnet,
          sourceWalletId: 'liquid-wallet',
          destinationWalletId: 'bitcoin-wallet',
          note: LabelSystem.autoSwap.label,
          quotedCounterpartAmountSat: any(named: 'quotedCounterpartAmountSat'),
        ),
      ).called(1);
    });

    test('other failures are not retried', () async {
      stubUpToCreate([const Err(SwapProviderFailure('nope'))]);

      await provider.execute(settings);

      expect(delays, isEmpty);
      verify(
        () => swapFacade.createOrder(
          amountSat: any(named: 'amountSat'),
          isInAmountFixed: true,
          inNetwork: OrderSwapNetwork.liquid,
          outNetwork: OrderSwapNetwork.bitcoin,
          destinationAddress: any(named: 'destinationAddress'),
          fallbackAddress: any(named: 'fallbackAddress'),
          purpose: OrderSwapPurpose.autoswap,
          environment: OrderSwapEnvironment.testnet,
          sourceWalletId: 'liquid-wallet',
          destinationWalletId: 'bitcoin-wallet',
          note: LabelSystem.autoSwap.label,
          quotedCounterpartAmountSat: any(named: 'quotedCounterpartAmountSat'),
        ),
      ).called(1);
    });
  });
}
