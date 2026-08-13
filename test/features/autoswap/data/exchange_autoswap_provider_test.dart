import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/autoswap/data/exchange_autoswap_provider.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockLiquidWalletRepository extends Mock
    implements LiquidWalletRepository {}

class _MockGetReceiveAddress extends Mock implements GetReceiveAddressUsecase {}

class _MockBroadcastLiquid extends Mock
    implements BroadcastLiquidTransactionUsecase {}

class _MockSwapFacade extends Mock implements SwapFacade {}

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
  late _MockSettingsRepository settingsRepository;
  late _MockLiquidWalletRepository liquidWalletRepository;
  late _MockGetReceiveAddress getReceiveAddress;
  late _MockBroadcastLiquid broadcastLiquid;
  late _MockSwapFacade swapFacade;
  late _MockLabelsFacade labelsFacade;
  late ExchangeAutoswapProvider provider;

  const settings = AutoSwap(
    enabled: true,
    showWarning: false,
    balanceThresholdSats: 500000,
    triggerBalanceSats: 1000000,
    feeThresholdPercent: 3,
    recipientWalletId: 'bitcoin-wallet',
  );

  setUpAll(() {
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
    settingsRepository = _MockSettingsRepository();
    liquidWalletRepository = _MockLiquidWalletRepository();
    getReceiveAddress = _MockGetReceiveAddress();
    broadcastLiquid = _MockBroadcastLiquid();
    swapFacade = _MockSwapFacade();
    labelsFacade = _MockLabelsFacade();
    provider = ExchangeAutoswapProvider(
      walletRepository,
      settingsRepository,
      liquidWalletRepository,
      getReceiveAddress,
      broadcastLiquid,
      swapFacade,
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
      () => swapFacade.getPendingOrders(),
    ).thenAnswer((_) async => const Ok([]));
    when(
      () => getReceiveAddress.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((invocation) async {
      final walletId = invocation.namedArguments[#walletId] as String;
      return WalletAddress(
        walletId: walletId,
        address: walletId == 'bitcoin-wallet'
            ? 'tb1qdestination000000000000000000000000000000'
            : 'tlq1fallback000000000000000000000000000000000',
        index: 0,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
    });
  });

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
      () => liquidWalletRepository.buildPset(
        walletId: 'liquid-wallet',
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        feeRate: any(named: 'feeRate'),
      ),
    ).thenAnswer((_) async => 'pset');
    when(
      () => liquidWalletRepository.getPsetSizeAndAbsoluteFees(pset: 'pset'),
    ).thenAnswer((_) async => (200, 500));
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
        note: 'Auto-Transfer',
        quotedCounterpartAmountSat: any(named: 'quotedCounterpartAmountSat'),
      ),
    ).thenAnswer((_) async => Ok(record));
    when(
      () => liquidWalletRepository.getAmountSentToAddress(
        pset: 'pset',
        address: record.order!.payinAddress,
        walletId: 'liquid-wallet',
      ),
    ).thenAnswer((_) async => 2499500);
    when(
      () => liquidWalletRepository.signPset(
        walletId: 'liquid-wallet',
        pset: 'pset',
      ),
    ).thenAnswer((_) async => 'signed-pset');
    when(
      () => swapFacade.savePreparedPayin(
        localId: 'local-id',
        signedTransaction: 'signed-pset',
        isPsbt: false,
      ),
    ).thenAnswer((_) async => Ok(prepared));
    when(
      () => swapFacade.markBroadcastUnknown('local-id'),
    ).thenAnswer((_) async => Ok(broadcasting));
    when(
      () => broadcastLiquid.execute('signed-pset', isTestnet: true),
    ).thenAnswer((_) async => 'txid');
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
          label: 'Auto-Transfer',
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
      () => broadcastLiquid.execute('signed-pset', isTestnet: true),
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
    when(
      () => swapFacade.getPendingOrders(),
    ).thenAnswer((_) async => Ok([prepared]));
    when(
      () => swapFacade.markBroadcastUnknown('local-id'),
    ).thenAnswer((_) async => Ok(broadcasting));
    when(
      () => broadcastLiquid.execute('signed-pset', isTestnet: true),
    ).thenAnswer((_) async => 'txid');
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
          label: 'Auto-Transfer',
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
    when(
      () => swapFacade.getPendingOrders(),
    ).thenAnswer((_) async => Ok([uncertain]));
    when(
      () => swapFacade.refreshOrder('local-id'),
    ).thenAnswer((_) async => Ok(paid));

    final result = await provider.execute(settings);

    expect(result, isA<Ok<String, AutoswapFailure>>());
    verify(() => swapFacade.refreshOrder('local-id')).called(1);
    verifyNever(
      () => broadcastLiquid.execute(any(), isTestnet: any(named: 'isTestnet')),
    );
  });

  test('rebroadcasts the persisted signed payin after a crash before broadcast '
      'was confirmed', () async {
    final uncertain = _record(
      status: OrderSwapLocalStatus.broadcastUnknown,
      signedTransaction: 'signed-pset',
    );
    when(
      () => swapFacade.getPendingOrders(),
    ).thenAnswer((_) async => Ok([uncertain]));
    when(
      () => swapFacade.refreshOrder('local-id'),
    ).thenAnswer((_) async => Ok(uncertain));
    when(
      () => swapFacade.markBroadcastUnknown('local-id'),
    ).thenAnswer((_) async => Ok(uncertain));
    when(
      () => broadcastLiquid.execute('signed-pset', isTestnet: true),
    ).thenAnswer((_) async => 'txid');
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
          label: 'Auto-Transfer',
        ),
      ),
    );

    final result = await provider.execute(settings);

    expect(result, isA<Ok<String, AutoswapFailure>>());
    expect((result as Ok<String, AutoswapFailure>).value, 'local-id');
    verify(() => swapFacade.refreshOrder('local-id')).called(1);
    verify(
      () => broadcastLiquid.execute('signed-pset', isTestnet: true),
    ).called(1);
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
    when(
      () => swapFacade.getPendingOrders(),
    ).thenAnswer((_) async => Ok([uncertain]));
    when(
      () => swapFacade.refreshOrder('local-id'),
    ).thenAnswer((_) async => Ok(observed));

    final result = await provider.execute(settings);

    expect(result, isA<Ok<String, AutoswapFailure>>());
    verify(() => swapFacade.refreshOrder('local-id')).called(1);
    verifyNever(
      () => broadcastLiquid.execute(any(), isTestnet: any(named: 'isTestnet')),
    );
  });

  test(
    'returns a typed failure when the persisted payin cannot be broadcast',
    () async {
      final uncertain = _record(
        status: OrderSwapLocalStatus.broadcastUnknown,
        signedTransaction: 'signed-pset',
      );
      when(
        () => swapFacade.getPendingOrders(),
      ).thenAnswer((_) async => Ok([uncertain]));
      when(
        () => swapFacade.refreshOrder('local-id'),
      ).thenAnswer((_) async => Ok(uncertain));
      when(
        () => swapFacade.markBroadcastUnknown('local-id'),
      ).thenAnswer((_) async => Ok(uncertain));
      when(
        () => broadcastLiquid.execute('signed-pset', isTestnet: true),
      ).thenThrow(Exception('rejected: transaction is not final'));

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
}
