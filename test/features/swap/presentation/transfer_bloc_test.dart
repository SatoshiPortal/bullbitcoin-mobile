import '../../../../features/send/test/payment/testing/send_spend_test_double.dart'
    show
        PreparedBitcoinSend,
        SignLiquidTxUsecase,
        BroadcastLiquidTransactionUsecase,
        CalculateLiquidAbsoluteFeesUsecase,
        BroadcastBitcoinTransactionUsecase,
        CalculateBitcoinAbsoluteFeesUsecase,
        SignBitcoinTxUsecase,
        InsufficientFundsException,
        NoSpendableUtxoException,
        WalletSpendBlockedException,
        CategorizedBroadcastException,
        BroadcastFailureCategory;

import 'package:coins/coins.dart';
import 'package:secrets/testing.dart';
import 'package:secrets/secrets.dart' show WalletSigner;
import 'package:primitives/primitives.dart'
    show Network, BitcoinNetwork, LiquidNetwork, NetworkEnv;
import 'package:swap_feature/testing.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;

import 'package:satoshifier/payment_request.dart';
import 'package:swaps/order_swaps.dart';
import 'package:spend/spend.dart';
import 'package:spend/testing.dart';
import 'package:primitives/primitives.dart' as primitives;

import 'package:sync/sync.dart' as native;

import 'dart:async';
import 'dart:typed_data';

import 'package:spend/legacy_exceptions.dart';
import 'package:fees/fees.dart';
import 'package:preferences/preferences.dart';
import 'package:swaps/swaps.dart' hide Environment;
import 'package:swaps/swaps.dart' as swaps show Environment;
import 'package:sync/sync.dart' show BitcoinSpendStatus;
import 'package:address_view/address_view.dart';
import 'package:send/send.dart';
import 'package:address_view/payment_destination.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart'
    show MaterialApp, Builder, SizedBox, Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:transactions/transactions.dart' show Transactions;
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' hide Network, ScriptType;

abstract interface class _ValidateBitcoinSelection {
  Future<Result<void, SpendFailure>> execute({
    required String walletId,
    Set<primitives.Outpoint>? selectedInputs,
  });
}

abstract interface class PrepareLiquidSendUsecase {
  Future<Result<String, SpendFailure>> execute({
    required String walletId,
    required String address,
    required RelativeFee feeRate,
    int? amountSat,
    bool drain = false,
    Set<primitives.Outpoint>? selectedInputs,
    bool hasFrozenInputs = false,
  });
}

abstract interface class PrepareBitcoinSendUsecase {
  Future<Result<PreparedBitcoinSend, SendFailure>> execute({
    required String walletId,
    required List<primitives.BitcoinTransactionRecipient> recipients,
    required NetworkFee networkFee,
    List<WalletUtxo>? selectedInputs,
    bool selectedOnly = false,
    bool replaceByFee = true,
  });
}

class _MockGetSettings extends Mock implements Preferences {}

class _MockTransactions extends Mock implements Transactions {}

class _MockGetWallets extends Mock implements LoadSwapWalletsUsecase {}

class _MockGetNetworkFees extends Mock implements Fees {}

class _MockPrepareBitcoin extends Mock implements PrepareBitcoinSendUsecase {}

class _MockValidateBitcoinSelection extends Mock
    implements _ValidateBitcoinSelection {}

class _MockPrepareLiquid extends Mock implements PrepareLiquidSendUsecase {}

class _MockCalculateBitcoin extends Mock
    implements CalculateBitcoinAbsoluteFeesUsecase {}

class _MockCalculateLiquid extends Mock
    implements CalculateLiquidAbsoluteFeesUsecase {}

class _MockSignBitcoin extends Mock implements SignBitcoinTxUsecase {}

class _MockSignLiquid extends Mock implements SignLiquidTxUsecase {}

class _MockBroadcastBitcoin extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

class _MockBroadcastLiquid extends Mock
    implements BroadcastLiquidTransactionUsecase {}

class _MockVerifyChain extends Mock implements VerifyTransferLockupUsecase {}

class _MockDetectBitcoin extends Mock implements DetectBitcoinStringUsecase {}

class _MockGetReceiveAddress extends Mock implements AddressView {}

class _MockGetUtxos extends Mock implements ReadSwapCoinsUsecase {}

class _MockGetExchangeRate extends Mock implements GetSwapExchangeRateUsecase {}

class _MockCheckConsolidation extends Mock implements Consolidation {}

class _MockGetSwapRoute extends Mock implements GetSwapRouteUsecase {}

class _MockGetLimitsAndFees extends Mock
    implements GetSwapLimitsAndFeesUsecase {}

class _MockCreateBitcoinToLiquidSwap extends Mock
    implements CreateBitcoinToLiquidSwapUsecase {}

class _MockCreateLiquidToBitcoinSwap extends Mock
    implements CreateLiquidToBitcoinSwapUsecase {}

class _MockRecordLockup extends Mock implements RecordSwapLockupUsecase {}

class _MockRecordPendingLockup extends Mock
    implements RecordPendingSwapLockupUsecase {}

class _MockDropPendingLockup extends Mock
    implements DropPendingSwapLockupUsecase {}

class _MockWatchSwap extends Mock implements WatchSwapUsecase {}

Matcher _paysTo(String address, {int? amountSat}) =>
    predicate<List<BitcoinTransactionRecipient>>(
      (recipients) =>
          recipients.length == 1 &&
          recipients.single.address == address &&
          recipients.single.amountSat ==
              (amountSat == null ? null : Sats.fromInt(amountSat)),
    );

Matcher _toWallet(String walletId) =>
    isA<ToWallet>().having((d) => d.walletId, 'walletId', walletId);

Matcher _toAddress(String address) =>
    isA<ToAddress>().having((d) => d.address, 'address', address);

class _MockOrders extends Mock implements OrderSwaps {}

class _MockAdmission extends Mock implements CheckSwapSpendAdmissionUsecase {}

class _DelayedAnimations implements PaymentAnimationPreferencesReader {
  final Completer<Result<bool, PreferencesFailure>> _read;

  _DelayedAnimations(this._read);

  @override
  Future<Result<bool, PreferencesFailure>> readShowPaymentAnimations() =>
      _read.future;
}

void main() {
  late _MockOrders orders;
  final synchronizedWallets = <native.WalletKey>[];

  void verifyOrderWasNotCreated() {
    verifyNever(
      () => orders.createOrder(
        amountSat: any(named: 'amountSat'),
        isInAmountFixed: any(named: 'isInAmountFixed'),
        inNetwork: any(named: 'inNetwork'),
        outNetwork: any(named: 'outNetwork'),
        destinationAddress: any(named: 'destinationAddress'),
        fallbackAddress: any(named: 'fallbackAddress'),
        purpose: any(named: 'purpose'),
        environment: any(named: 'environment'),
      ),
    );
  }

  setUpAll(() {
    registerFallbackValue(_wallet().key);
    registerFallbackValue(NetworkEnv.testnet);
    registerFallbackValue(BitcoinNetwork.mainnet);
    registerFallbackValue(OrderSwapPurpose.transfer);
    registerFallbackValue(SwapType.bitcoinToLiquid);
    registerFallbackValue(const ToWallet(''));
    registerFallbackValue(const RelativeFee(250));
    registerFallbackValue(OrderSwapEnvironment.mainnet);
    registerFallbackValue(OrderSwapNetwork.bitcoin);
    registerFallbackValue(BigInt.zero);
    registerFallbackValue(BigInt.zero);
  });

  late _MockPrepareLiquid prepareLiquid;
  late _MockSignLiquid signLiquid;
  late _MockBroadcastLiquid broadcastLiquid;
  late BitcoinSpendStatus spendStatus;
  late _MockAdmission admission;
  late _MockBroadcastBitcoin broadcastBitcoin;
  BitcoinSpendPreview? preview;
  late _MockGetSettings getSettings;
  late _MockGetWallets getWallets;
  late _MockGetNetworkFees getNetworkFees;
  late _MockGetExchangeRate getExchangeRate;
  late _MockPrepareBitcoin prepareBitcoin;
  late _MockValidateBitcoinSelection validateBitcoinSelection;
  late _MockCalculateBitcoin calculateBitcoin;
  late _MockCalculateLiquid calculateLiquid;
  late _MockGetReceiveAddress getReceiveAddress;
  late _MockGetUtxos getUtxos;
  late _MockSignBitcoin signBitcoin;
  late _MockVerifyChain verifyChain;
  late _MockGetSwapRoute getSwapRoute;
  late _MockGetLimitsAndFees getLimitsAndFees;
  late _MockCreateBitcoinToLiquidSwap createBitcoinToLiquid;
  late _MockCreateLiquidToBitcoinSwap createLiquidToBitcoin;
  late _MockRecordLockup recordLockup;
  late _MockRecordPendingLockup recordPendingLockup;
  late _MockDropPendingLockup dropPendingLockup;
  late _MockWatchSwap watchSwap;
  late _MockDetectBitcoin detectBitcoin;
  late OrderSwapRecord prepared;
  late TransferBloc bloc;

  TransferBloc buildBloc({
    BroadcastBitcoinTransactionUsecase? bitcoinBroadcast,
    GetSwapAmountQuotesUsecase? amountQuotes,
    ReadTransferPaymentAnimationsUsecase? readPaymentAnimations,
  }) {
    late final TransferBloc flow;
    flow = TransferBloc(
      watchSettlement: WatchTransferSettlementUsecase(_MockTransactions()),
      loadPreferencesUsecase: LoadTransferPreferencesUsecase(getSettings),
      getSwapAmountQuotesUsecase: amountQuotes,
      getWalletsUsecase: getWallets,
      loadNetworkFeesUsecase: LoadTransferNetworkFeesUsecase(
        fees: getNetworkFees,
      ),
      spend: _SwapSpend(
        read: () => flow.state,
        btc: prepareBitcoin,
        selection: validateBitcoinSelection,
        lbtc: prepareLiquid,
        btcFees: calculateBitcoin,
        liquidFees: calculateLiquid,
        btcSign: signBitcoin,
        liquidSign: signLiquid,
        btcBroadcast: bitcoinBroadcast ?? broadcastBitcoin,
        liquidBroadcast: broadcastLiquid,
        readPreview: () => preview,
      ),
      synchronizeWallet: (key) async {
        synchronizedWallets.add(key);
        return const Ok(null);
      },
      orders: orders,
      verifyChainSwapAmountSendUsecase: verifyChain,
      checkSwapSpendAdmissionUsecase: admission,
      detectBitcoinStringUsecase: detectBitcoin,
      getReceiveAddressUsecase: getReceiveAddress,
      getCoinsUsecase: getUtxos,
      getSwapExchangeRateUsecase: getExchangeRate,
      consolidation: _MockCheckConsolidation(),
      getSwapRouteUsecase: getSwapRoute,
      getSwapLimitsAndFeesUsecase: getLimitsAndFees,
      createBitcoinToLiquidSwapUsecase: createBitcoinToLiquid,
      createLiquidToBitcoinSwapUsecase: createLiquidToBitcoin,
      recordSwapLockupUsecase: recordLockup,
      recordPendingSwapLockupUsecase: recordPendingLockup,
      dropPendingSwapLockupUsecase: dropPendingLockup,
      watchSwapUsecase: watchSwap,
      readPaymentAnimationsUsecase: readPaymentAnimations,
    );
    return flow;
  }

  setUp(() {
    orders = _MockOrders();
    synchronizedWallets.clear();
    prepareLiquid = _MockPrepareLiquid();
    signLiquid = _MockSignLiquid();
    broadcastLiquid = _MockBroadcastLiquid();
    spendStatus = BitcoinSpendStatus.ready;
    admission = _MockAdmission();
    when(() => admission.execute(any())).thenAnswer((invocation) async {
      expect(
        (invocation.positionalArguments.single as native.WalletKey).id,
        'wallet-1',
      );
      return spendStatus == BitcoinSpendStatus.ready
          ? const Ok(null)
          : Err(SwapSpendBlockedFailure(spendStatus));
    });
    broadcastBitcoin = _MockBroadcastBitcoin();
    preview = null;
    getSettings = _MockGetSettings();
    getWallets = _MockGetWallets();
    getNetworkFees = _MockGetNetworkFees();
    getExchangeRate = _MockGetExchangeRate();
    prepareBitcoin = _MockPrepareBitcoin();
    validateBitcoinSelection = _MockValidateBitcoinSelection();
    calculateBitcoin = _MockCalculateBitcoin();
    calculateLiquid = _MockCalculateLiquid();
    when(() => calculateBitcoin.execute(psbt: any(named: 'psbt')))
        .thenAnswer((_) async => 200);
    when(() => calculateLiquid.execute(pset: any(named: 'pset')))
        .thenAnswer((_) async => 200);
    getReceiveAddress = _MockGetReceiveAddress();
    getUtxos = _MockGetUtxos();
    signBitcoin = _MockSignBitcoin();
    verifyChain = _MockVerifyChain();
    getSwapRoute = _MockGetSwapRoute();
    getLimitsAndFees = _MockGetLimitsAndFees();
    createBitcoinToLiquid = _MockCreateBitcoinToLiquidSwap();
    createLiquidToBitcoin = _MockCreateLiquidToBitcoinSwap();
    recordLockup = _MockRecordLockup();
    recordPendingLockup = _MockRecordPendingLockup();
    dropPendingLockup = _MockDropPendingLockup();
    when(() => dropPendingLockup.execute(any()))
        .thenAnswer((_) async => const Ok(null));
    when(
      () => recordPendingLockup.execute(
        swapId: any(named: 'swapId'),
        signedTx: any(named: 'signedTx'),
      ),
    ).thenAnswer((_) async => Ok(_swap()));
    watchSwap = _MockWatchSwap();
    detectBitcoin = _MockDetectBitcoin();
    prepared = _prepared();
    when(() => getSwapRoute.execute())
        .thenAnswer((_) async => SwapRoute.exchange);
    when(() => watchSwap.execute(any()))
        .thenAnswer((_) => const Stream<Swap>.empty());
    when(
      () => validateBitcoinSelection.execute(
        walletId: any(named: 'walletId'),
        selectedInputs: any(named: 'selectedInputs'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => getReceiveAddress.receiveAddress(walletId: any(named: 'walletId')),
    ).thenAnswer(
      (_) async => Ok(
        WalletAddress(
          walletId: 'wallet-2',
          index: 0,
          address: 'destination',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      ),
    );

    bloc = buildBloc();
  });

  tearDown(() => bloc.close());

  test('late quotes and input notifications cannot change a confirmed direct transfer', () async {
    when(getSettings.fetch).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.testnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      ),
    );
    var reads = 0;
    final pending =
        Completer<
          Result<Map<SupportedCurrency, BitcoinPrice>, PricerFailure>
        >();
    final quotes = GetSwapAmountQuotesUsecase(
      settings: getSettings,
      read: ({required network}) {
        reads++;
        return pending.future;
      },
    );
    final flow = buildBloc(amountQuotes: quotes);
    addTearDown(flow.close);
    flow.emit(const TransferState(amount: '25000'));
    flow.add(const TransferEvent.amountQuotesRequested());
    await pumpEventQueue();
    expect(reads, 1);
    flow.emit(flow.state.copyWith(signedPsbt: 'signed'));
    pending.complete(
      Ok({
        SupportedCurrency.cad: BitcoinPrice(
          currency: SupportedCurrency.cad,
          fiatAmount: 100000,
          fetchedAt: DateTime.utc(2026),
        ),
      }),
    );
    await pumpEventQueue();
    expect(flow.state.amountQuotes, isEmpty);
    flow.add(
      TransferEvent.amountEntryChanged(
        sats: BigInt.from(31250),
        currencyCode: 'CAD',
        text: '31.25',
        rate: 100000,
        quotedAt: DateTime.utc(2026),
        isValid: true,
        isEdit: true,
      ),
    );
    await pumpEventQueue();
    expect(flow.state.signedPsbt, 'signed');
    expect(flow.state.inputAmountSat, 25000);
    flow.add(const TransferEvent.amountEditingResumed());
    await pumpEventQueue();
    expect(flow.state.signedPsbt, isEmpty);
    expect(flow.state.amountQuotes[SupportedCurrency.cad]?.fiatAmount, 100000);
  });

  test('changing the source wallet keeps the canonical Max in sync', () async {
    final source = _wallet(balanceSat: BigInt.from(10000));
    final replacement = source.copyWith(
      origin: 'empty',
      balanceSat: BigInt.zero,
    );
    final destination = _destinationWallet();
    bloc.emit(
      TransferState(
        fromWallet: source,
        toWallet: destination,
        amount: '9000',
        maxAmountSat: 9000,
        maxSelected: true,
      ),
    );
    bloc.add(
      TransferEvent.walletsChanged(
        fromWallet: replacement,
        toWallet: destination,
      ),
    );
    await pumpEventQueue();
    expect(bloc.state.maxAmountSat, 0);
    expect(bloc.state.inputAmountSat, 0);
  });

  test('BIP21 one-sat amounts remain exact with BTC display', () async {
    when(
      () => detectBitcoin.execute(
        data: 'bitcoin:one-sat',
        environment: any(named: 'environment'),
      ),
    ).thenAnswer(
      (_) async => const PaymentRequest.bip21(
        network: BitcoinNetwork.testnet,
        uri: 'bitcoin:fixture?amount=0.00000001',
        address: 'tb1qfixture',
        amountSat: 1,
      ),
    );
    bloc.emit(
      TransferState(
        fromWallet: _liquidWallet(),
        sendToExternal: true,
        bitcoinUnit: BitcoinUnit.btc,
      ),
    );
    bloc.add(const TransferEvent.externalAddressChanged('bitcoin:one-sat'));
    await pumpEventQueue();
    expect(bloc.state.inputAmountSat, 1);
  });

  test('a BIP21 amount replaces the previous Max and fiat intent', () async {
    when(
      () => detectBitcoin.execute(
        data: 'bitcoin:fixture',
        environment: any(named: 'environment'),
      ),
    ).thenAnswer(
      (_) async => const PaymentRequest.bip21(
        network: BitcoinNetwork.testnet,
        uri: 'bitcoin:fixture?amount=0.000025',
        address: 'tb1qfixture',
        amountSat: 2500,
      ),
    );
    bloc.emit(
      TransferState(
        fromWallet: _liquidWallet(),
        sendToExternal: true,
        amount: '10000',
        maxAmountSat: 10000,
        maxSelected: true,
      ),
    );
    bloc.add(const TransferEvent.externalAddressChanged('bitcoin:fixture'));
    await pumpEventQueue();
    expect(bloc.state.isMaxSelected, isFalse);
    expect(bloc.state.inputAmountSat, 2500);
    expect(bloc.state.amountConversion, isNull);
  });

  test(
    'the animations preference is unknown until read, then emitted',
    () async {
      final read = Completer<Result<bool, PreferencesFailure>>();
      final flow = buildBloc(
        readPaymentAnimations: ReadTransferPaymentAnimationsUsecase(
          _DelayedAnimations(read),
        ),
      );
      addTearDown(flow.close);
      expect(flow.state.showPaymentAnimations, isNull);
      read.complete(const Ok(false));
      await flow.stream.firstWhere((s) => s.showPaymentAnimations != null);
      expect(flow.state.showPaymentAnimations, isFalse);
    },
  );

  test('without a reader the animations stay on from the start', () {
    final flow = buildBloc();
    addTearDown(flow.close);
    expect(flow.state.showPaymentAnimations, isTrue);
  });

  test(
    'Max is explicit and editing the same number exits the intent',
    () async {
      bloc.emit(const TransferState(amount: '25000', maxAmountSat: 25000));
      expect(bloc.state.isMaxSelected, isFalse);
      bloc.add(const TransferEvent.maxSelected());
      await pumpEventQueue();
      expect(bloc.state.isMaxSelected, isTrue);
      expect(bloc.state.receiveExactAmount, isFalse);
      bloc.add(const TransferEvent.amountChanged('25000'));
      await pumpEventQueue();
      expect(bloc.state.isMaxSelected, isFalse);
      expect(bloc.state.inputAmountSat, 25000);
    },
  );

  test('destination switch clears the old receive address', () async {
    final source = _wallet(balanceSat: BigInt.zero);
    final destination = _destinationWallet();
    final replacement = _destinationWallet(id: 'wallet-3');
    bloc.emit(
      TransferState(
        fromWallet: source,
        toWallet: destination,
        receiveAddress: 'old-wallet-2-address',
        amount: '1000',
        bitcoinUnit: BitcoinUnit.sats,
        bitcoinNetworkFees: _feeOptions(),
      ),
    );
    bloc.add(
      TransferEvent.walletsChanged(fromWallet: source, toWallet: replacement),
    );
    await pumpEventQueue();
    expect(bloc.state.toWallet?.id, 'wallet-3');
    expect(bloc.state.receiveAddress, isNull);
  });

  test(
    'returning to an internal recipient clears the external receive address',
    () async {
      bloc.emit(
        TransferState(
          fromWallet: _wallet(),
          toWallet: _destinationWallet(),
          sendToExternal: true,
          externalAddress: 'external',
          receiveAddress: 'external',
        ),
      );
      bloc.add(const TransferEvent.sendToExternalToggled(false));
      await pumpEventQueue();
      expect(bloc.state.receiveAddress, isNull);
    },
  );

  test(
    'an external address before a source wallet is a typed failure',
    () async {
      bloc.emit(const TransferState(sendToExternal: true));
      bloc.add(const TransferEvent.externalAddressChanged('bc1qaddress'));
      await pumpEventQueue();
      expect(
        bloc.state.externalAddressError,
        isA<SwapSourceWalletMissingFailure>(),
      );
    },
  );

  test('an unreadable external address asks for the payout network', () async {
    bloc.emit(TransferState(fromWallet: _wallet(), sendToExternal: true));
    bloc.add(const TransferEvent.externalAddressChanged('not an address'));
    await pumpEventQueue();
    expect(
      bloc.state.externalAddressError,
      isA<SwapInvalidExternalAddressFailure>().having(
        (f) => f.expectsBitcoin,
        'expectsBitcoin',
        false,
      ),
    );
  });

  for (final sameChain in [true, false]) {
    test(
      'accepted ${sameChain ? "same-chain" : "order-swap"} transfer broadcasts through the source wallet',
      () async {
        var broadcasts = 0;
        when(
          () => broadcastBitcoin.execute(
            'signed-psbt',
            isPsbt: true,
            network: BitcoinNetwork.testnet,
            walletId: 'wallet-1',
          ),
        ).thenAnswer((_) async {
          broadcasts++;
          return 'a' * 64;
        });
        when(() => orders.markBroadcastUnknown('local-1', requireReady: true))
            .thenAnswer(
              (_) async =>
                  Ok(_prepared(status: OrderSwapLocalStatus.broadcastUnknown)),
            );
        when(
          () => orders.markPayinBroadcast(
            localId: 'local-1',
            transactionId: 'a' * 64,
          ),
        ).thenAnswer(
          (_) async => Ok(
            _prepared(
              status: OrderSwapLocalStatus.payinBroadcast,
              transactionId: 'a' * 64,
            ),
          ),
        );
        bloc.emit(
          TransferState(
            fromWallet: _wallet(),
            toWallet: sameChain ? _destinationWallet() : null,
            signedPsbt: 'signed-psbt',
            bitcoinSignature: sameChain
                ? SpendFixtures.signedBitcoin('signed-psbt')
                : null,
            orderSwap: sameChain ? null : prepared,
            swap: sameChain ? null : _swap(),
          ),
        );
        bloc.add(const TransferEvent.confirmed());
        await bloc.stream.firstWhere((state) => !state.isConfirming);
        expect(bloc.state.txId, 'a' * 64);
        expect(broadcasts, 1);
      },
    );

    testWidgets(
      'refused ${sameChain ? "same-chain" : "order-swap"} transfer exposes spend failure without marking a payin broadcast',
      (tester) async {
        when(() => orders.markBroadcastUnknown('local-1', requireReady: true))
            .thenAnswer(
              (_) async =>
                  Ok(_prepared(status: OrderSwapLocalStatus.broadcastUnknown)),
            );
        when(
          () => broadcastBitcoin.execute(
            any(),
            isPsbt: any(named: 'isPsbt'),
            network: BitcoinNetwork.testnet,
            walletId: any(named: 'walletId'),
          ),
        ).thenThrow(
          const WalletSpendBlockedException(BitcoinSpendStatus.pending),
        );
        bloc.emit(
          TransferState(
            fromWallet: _wallet(),
            toWallet: sameChain ? _destinationWallet() : null,
            signedPsbt: 'signed-psbt',
            bitcoinSignature: sameChain
                ? SpendFixtures.signedBitcoin('signed-psbt')
                : null,
            orderSwap: sameChain ? null : prepared,
            swap: sameChain ? null : _swap(),
          ),
        );
        await tester.runAsync(() async {
          bloc.add(const TransferEvent.confirmed());
          await bloc.stream.firstWhere((state) => !state.isConfirming);
        });
        expect(bloc.state.swapFailure, isA<SwapSpendBlockedFailure>());
        expect(bloc.state.txId, isEmpty);
        expect(bloc.state.confirmTransactionException, isNull);
        expect(bloc.state.swap?.status, isNot(SwapStatus.paid));
        expect(bloc.state.orderSwap?.localPayinTransactionId, isNull);
        if (!sameChain) {
          expect(
            bloc.state.orderSwap?.localStatus,
            OrderSwapLocalStatus.broadcastUnknown,
          );
        }
        verifyNever(
          () => orders.markPayinBroadcast(
            localId: any(named: 'localId'),
            transactionId: any(named: 'transactionId'),
          ),
        );
        expect(synchronizedWallets, isEmpty);
        final failure = bloc.state.swapFailure;
        expect(failure, isNotNull);
        if (failure == null) return;
        String? message;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                message = failure.toTranslated(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(message, l10n.walletSpendAwaitingObservation);
      },
    );
  }

  test('blocked source refuses before creating an exchange order', () async {
    spendStatus = BitcoinSpendStatus.pending;
    when(() => getReceiveAddress.receiveAddress(walletId: 'wallet-1'))
        .thenAnswer(
          (_) async => Ok(
            WalletAddress(
              walletId: 'wallet-1',
              index: 0,
              address: 'fallback',
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          ),
        );
    when(
      () => orders.getQuote(
        environment: OrderSwapEnvironment.testnet,
        amountSat: any(named: 'amountSat'),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.bitcoin,
        outNetwork: OrderSwapNetwork.liquid,
      ),
    ).thenAnswer(
      (_) async => Ok(
        OrderSwapQuote(
          inAmountSat: BigInt.from(1000),
          outAmountSat: BigInt.from(900),
          inNetwork: OrderSwapNetwork.bitcoin,
          outNetwork: OrderSwapNetwork.liquid,
          inCurrency: 'BTC',
          outCurrency: 'L-BTC',
          feeBasisPoints: 0,
          warnings: [],
        ),
      ),
    );
    when(
      () => orders.createOrder(
        amountSat: any(named: 'amountSat'),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.bitcoin,
        outNetwork: OrderSwapNetwork.liquid,
        destinationAddress: any(named: 'destinationAddress'),
        fallbackAddress: any(named: 'fallbackAddress'),
        purpose: OrderSwapPurpose.transfer,
        environment: OrderSwapEnvironment.testnet,
        sourceWalletId: 'wallet-1',
        destinationWalletId: null,
        quotedCounterpartAmountSat: any(named: 'quotedCounterpartAmountSat'),
      ),
    ).thenAnswer((_) async => const Err(SwapProviderFailure()));
    bloc.emit(
      TransferState(
        fromWallet: _wallet(balanceSat: BigInt.from(2000)),
        sendToExternal: true,
        receiveExactAmount: false,
        externalAddress: 'destination',
        bitcoinUnit: BitcoinUnit.sats,
        bitcoinNetworkFees: _feeOptions(),
      ),
    );
    bloc.add(const TransferEvent.swapCreated('1000'));
    await bloc.stream.firstWhere((state) => !state.isCreatingSwap);
    verifyOrderWasNotCreated();
    expect(bloc.state.swapFailure, isA<SwapSpendBlockedFailure>());
    expect(bloc.state.orderSwap, isNull);
    verifyZeroInteractions(prepareBitcoin);
  });

  void stubLiquidCreation(
    Future<Result<String, SpendFailure>> Function() prepare,
  ) {
    when(
      () => getReceiveAddress.receiveAddress(walletId: any(named: 'walletId')),
    ).thenAnswer(
      (_) async => Ok(
        WalletAddress(
          walletId: 'wallet-1',
          address: 'destination',
          index: 0,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      ),
    );
    when(
      () => orders.getQuote(
        environment: OrderSwapEnvironment.testnet,
        amountSat: BigInt.from(1000),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.bitcoin,
      ),
    ).thenAnswer(
      (_) async => Ok(
        OrderSwapQuote(
          inAmountSat: BigInt.from(1010),
          outAmountSat: BigInt.from(1000),
          inNetwork: OrderSwapNetwork.liquid,
          outNetwork: OrderSwapNetwork.bitcoin,
          inCurrency: 'LBTC',
          outCurrency: 'BTC',
          feeBasisPoints: 100,
          warnings: const [],
        ),
      ),
    );
    when(
      () => orders.createOrder(
        amountSat: BigInt.from(1000),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.bitcoin,
        destinationAddress: 'destination',
        fallbackAddress: 'destination',
        purpose: OrderSwapPurpose.transfer,
        environment: OrderSwapEnvironment.testnet,
        sourceWalletId: 'wallet-1',
        destinationWalletId: 'wallet-2',
        quotedCounterpartAmountSat: BigInt.from(1010),
      ),
    ).thenAnswer((_) async => Ok(_prepared()));
    when(
      () => prepareLiquid.execute(
        walletId: 'wallet-1',
        address: 'liquid-address',
        amountSat: 1010,
        feeRate: any(named: 'feeRate'),
        drain: false,
      ),
    ).thenAnswer((_) => prepare());
    bloc.emit(
      TransferState(
        fromWallet: _liquidWallet().copyWith(balanceSat: BigInt.from(2000)),
        toWallet: _destinationWallet(),
        liquidNetworkFees: _feeOptions(),
        signedPsbt: 'previous-pset',
      ),
    );
  }

  for (final failure in <SpendFailure>[
    const SpendConsolidationRequiredFailure(),
    const SpendBuildRefusedFailure(),
  ]) {
    test(
      'Liquid ${failure.runtimeType} stops verification and signing',
      () async {
        stubLiquidCreation(() async => Err(failure));
        bloc.add(const TransferEvent.swapCreated('1000'));
        await bloc.stream.firstWhere((state) => !state.isCreatingSwap);
        verify(
          () => prepareLiquid.execute(
            walletId: 'wallet-1',
            address: 'liquid-address',
            amountSat: 1010,
            feeRate: any(named: 'feeRate'),
            drain: false,
          ),
        ).called(1);
        expect(bloc.state.signedPsbt, isEmpty);
        expect(
          bloc.state.consolidationRequired,
          failure is SpendConsolidationRequiredFailure,
        );
        expect(bloc.state.swapCreationException, isNotNull);
        expect(bloc.state.isCreatingSwap, isFalse);
        verifyZeroInteractions(verifyChain);
        verifyZeroInteractions(signLiquid);
        verifyZeroInteractions(broadcastLiquid);
      },
    );
  }

  test(
    'blocked confirmation preserves prepared payin and permits a later edit',
    () async {
      spendStatus = BitcoinSpendStatus.unavailable;
      when(() => orders.markBroadcastUnknown('local-1', requireReady: true))
          .thenAnswer(
            (_) async =>
                Ok(_prepared(status: OrderSwapLocalStatus.broadcastUnknown)),
          );
      bloc.emit(
        TransferState(
          fromWallet: _wallet(balanceSat: BigInt.from(100000)),
          toWallet: _liquidWallet(id: 'wallet-2'),
          swap: _swap(),
          orderSwap: prepared,
          amount: '1000',
          bitcoinUnit: BitcoinUnit.sats,
          bitcoinNetworkFees: _feeOptions(),
          signedPsbt: 'signed-psbt',
        ),
      );
      bloc.add(const TransferEvent.confirmed());
      await bloc.stream.firstWhere((state) => !state.isConfirming);
      verifyNever(
        () => orders.markBroadcastUnknown(
          any(),
          requireReady: any(named: 'requireReady'),
        ),
      );
      expect(bloc.state.swapFailure, isA<SwapSpendBlockedFailure>());
      verifyNever(
        () => orders.markPayinBroadcast(
          localId: any(named: 'localId'),
          transactionId: any(named: 'transactionId'),
        ),
      );
      verifyZeroInteractions(broadcastBitcoin);
      expect(bloc.state.orderSwap, same(prepared));
      expect(bloc.state.signedPsbt, 'signed-psbt');

      spendStatus = BitcoinSpendStatus.ready;
      when(
        () => prepareBitcoin.execute(
          walletId: 'wallet-1',
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          selectedInputs: any(named: 'selectedInputs'),
          replaceByFee: false,
        ),
      ).thenAnswer(
        (_) async => Ok((
          unsignedPsbt: 'edited',
          txSize: 100,
          isToSelf: false,
          recipientAmountsSat: const <Sats>[],
        )),
      );
      when(
        () => verifyChain.execute(
          psbtOrPset: 'edited',
          swap: _swap(),
          wallet: _wallet().key,
        ),
      ).thenAnswer((_) async => const Ok(null));
      when(() => signBitcoin.execute(walletId: 'wallet-1', psbt: 'edited'))
          .thenAnswer((_) async => (signedPsbt: 'edited-signed', txSize: 100));
      when(() => calculateBitcoin.execute(psbt: 'edited-signed'))
          .thenAnswer((_) async => 1200);
      when(
        () => orders.replacePreparedPayin(
          localId: 'local-1',
          signedTransaction: 'edited-signed',
          isPsbt: true,
        ),
      ).thenAnswer((_) async => Ok(prepared));
      bloc.add(const TransferEvent.replaceByFeeChanged(false));
      await pumpEventQueue();
      verify(
        () => orders.replacePreparedPayin(
          localId: 'local-1',
          signedTransaction: 'edited-signed',
          isPsbt: true,
        ),
      ).called(1);
      expect(bloc.state.signedPsbt, 'edited-signed');
      expect(bloc.state.buildTransactionException, isNull);
      expect(
        bloc.state.orderSwap?.localStatus,
        OrderSwapLocalStatus.readyToBroadcast,
      );
    },
  );

  test('missing network fees block creation with a typed failure', () async {
    bloc.emit(
      TransferState(
        fromWallet: _wallet(balanceSat: BigInt.from(2000)),
        toWallet: _destinationWallet(),
        bitcoinUnit: BitcoinUnit.sats,
      ),
    );
    bloc.add(const TransferEvent.swapCreated('1000'));
    await bloc.stream.firstWhere((state) => !state.isCreatingSwap);
    expect(bloc.state.swapFailure, isA<SwapInvalidStateFailure>());
    expect(bloc.state.signedPsbt, isEmpty);
  });

  test('blocked transfer build exposes spend failure', () async {
    when(
      () => prepareBitcoin.execute(
        walletId: any(named: 'walletId'),
        recipients: any(named: 'recipients'),
        networkFee: any(named: 'networkFee'),
        selectedInputs: any(named: 'selectedInputs'),
        replaceByFee: any(named: 'replaceByFee'),
      ),
    ).thenThrow(const WalletSpendBlockedException(BitcoinSpendStatus.pending));
    bloc.emit(
      TransferState(
        fromWallet: _wallet(balanceSat: BigInt.from(2000)),
        toWallet: _destinationWallet(),
        receiveAddress: 'destination',
        bitcoinUnit: BitcoinUnit.sats,
        bitcoinNetworkFees: _feeOptions(),
      ),
    );
    bloc.add(const TransferEvent.swapCreated('1000'));
    await bloc.stream.firstWhere((state) => !state.isCreatingSwap);
    expect(bloc.state.swapFailure, isA<SwapSpendBlockedFailure>());
    expect(bloc.state.swapCreationException, isNull);
    expect(bloc.state.signedPsbt, isEmpty);
  });

  test(
    'blocked transfer rebuild exposes spend failure and clears stale PSBT',
    () async {
      when(
        () => prepareBitcoin.execute(
          walletId: any(named: 'walletId'),
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          selectedInputs: any(named: 'selectedInputs'),
          replaceByFee: any(named: 'replaceByFee'),
        ),
      ).thenThrow(
        const WalletSpendBlockedException(BitcoinSpendStatus.pending),
      );
      bloc.emit(
        TransferState(
          fromWallet: _wallet(),
          toWallet: _destinationWallet(),
          receiveAddress: 'destination',
          amount: '1000',
          bitcoinUnit: BitcoinUnit.sats,
          signedPsbt: 'stale',
          bitcoinNetworkFees: _feeOptions(),
        ),
      );
      bloc.add(const TransferEvent.feeOptionSelected(FeeSelection.fastest));
      await pumpEventQueue();
      expect(bloc.state.swapFailure, isA<SwapSpendBlockedFailure>());
      expect(bloc.state.buildTransactionException, isNull);
      expect(bloc.state.signedPsbt, isEmpty);
    },
  );

  test(
    'exposes insufficient funds when same-chain creation raises a shortfall',
    () async {
      final source = _wallet(balanceSat: BigInt.from(2000));
      final destination = _destinationWallet();
      when(
        () => prepareBitcoin.execute(
          walletId: source.id,
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          selectedInputs: any(named: 'selectedInputs'),
          replaceByFee: true,
        ),
      ).thenThrow(InsufficientFundsException('shortfall'));
      bloc.emit(
        TransferState(
          fromWallet: source,
          toWallet: destination,
          receiveAddress: 'tb1qdestination',
          bitcoinUnit: BitcoinUnit.sats,
          bitcoinNetworkFees: _feeOptions(),
        ),
      );

      bloc.add(const TransferEvent.swapCreated('1000'));
      await bloc.stream.firstWhere((state) => !state.isCreatingSwap);

      expect(
        bloc.state.swapCreationException,
        isA<InsufficientFundsSwapException>(),
      );
    },
  );

  test(
    'maps selected-coin rebuild shortfall to the insufficient code',
    () async {
      final selected = _bitcoinUtxo('selected-tx');
      when(
        () => prepareBitcoin.execute(
          walletId: 'wallet-1',
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          selectedInputs: [_legacyCoin(selected, 'wallet-1')],
          replaceByFee: true,
        ),
      ).thenThrow(InsufficientFundsException('shortfall'));
      bloc.emit(
        TransferState(
          fromWallet: _wallet(balanceSat: BigInt.from(100000)),
          toWallet: _destinationWallet(),
          receiveAddress: 'tb1qreceive',
          amount: '1000',
          selectedUtxos: [selected],
          signedPsbt: 'stale-psbt',
          bitcoinNetworkFees: _feeOptions(),
        ),
      );

      bloc.add(const TransferEvent.feeOptionSelected(FeeSelection.fastest));
      await bloc.stream.firstWhere(
        (state) => state.buildTransactionException != null,
      );

      expect(
        bloc.state.buildTransactionException?.message,
        selectedCoinsInsufficientCode,
      );
    },
  );

  test('maps unavailable selected coins in the cached rebuild path', () async {
    final selected = _bitcoinUtxo('selected-tx');
    when(
      () => validateBitcoinSelection.execute(
        walletId: 'wallet-1',
        selectedInputs: {selected.outpoint},
      ),
    ).thenAnswer(
      (_) async => const Err(SpendSelectedInputsUnavailableFailure()),
    );
    preview = (
      fee: Sats.fromInt(250),
      prepared: SpendFixtures.preparedBitcoin(
        unsignedPsbt: 'cached-unsigned-psbt',
        fee: Sats.fromInt(250),
        txSize: 100,
      ),
    );
    bloc.emit(
      TransferState(
        fromWallet: _wallet(balanceSat: BigInt.from(100000)),
        toWallet: _destinationWallet(),
        receiveAddress: 'tb1qreceive',
        amount: '1000',
        selectedUtxos: [selected],
        bitcoinNetworkFees: _feeOptions(),
      ),
    );

    final priced = bloc.stream.firstWhere(
      (state) => state.feePreviewCache.fastest.feeSat == 250,
    );
    bloc.add(const TransferEvent.presetFeesPreviewRequested());
    await priced;
    bloc.add(const TransferEvent.feeOptionSelected(FeeSelection.fastest));
    await bloc.stream.firstWhere(
      (state) => state.buildTransactionException != null,
    );

    expect(
      bloc.state.buildTransactionException?.message,
      selectedCoinsUnavailableCode,
    );
  });

  test(
    'maps unavailable selected coins in the non-cached rebuild path',
    () async {
      final selected = _bitcoinUtxo('selected-tx');
      when(
        () => prepareBitcoin.execute(
          walletId: 'wallet-1',
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          selectedInputs: [_legacyCoin(selected, 'wallet-1')],
          replaceByFee: true,
        ),
      ).thenThrow(NoSpendableUtxoException('selected coin disappeared'));
      bloc.emit(
        TransferState(
          fromWallet: _wallet(balanceSat: BigInt.from(100000)),
          toWallet: _destinationWallet(),
          receiveAddress: 'tb1qreceive',
          amount: '1000',
          selectedUtxos: [selected],
          signedPsbt: 'stale-psbt',
          bitcoinNetworkFees: _feeOptions(),
        ),
      );

      bloc.add(const TransferEvent.feeOptionSelected(FeeSelection.fastest));
      await bloc.stream.firstWhere(
        (state) => state.buildTransactionException != null,
      );

      expect(
        bloc.state.buildTransactionException?.message,
        selectedCoinsUnavailableCode,
      );
      expect(bloc.state.signedPsbt, isEmpty);
      verifyNever(
        () => broadcastBitcoin.execute(
          any(),
          isPsbt: any(named: 'isPsbt'),
          network: BitcoinNetwork.testnet,
          walletId: 'wallet-1',
        ),
      );
    },
  );

  test(
    'broadcasts a prepared order swap and emits its transaction id',
    () async {
      final broadcasting = _prepared(
        status: OrderSwapLocalStatus.broadcastUnknown,
      );
      final broadcasted = _prepared(
        status: OrderSwapLocalStatus.payinBroadcast,
        transactionId: 'txid-1',
      );
      when(() => orders.markBroadcastUnknown('local-1', requireReady: true))
          .thenAnswer((_) async => Ok(broadcasting));
      when(() => orders.refreshOrder('local-1'))
          .thenAnswer((_) async => Ok(broadcasting));
      when(
        () => broadcastBitcoin.execute(
          'signed-psbt',
          isPsbt: true,
          network: BitcoinNetwork.testnet,
          walletId: 'wallet-1',
        ),
      ).thenAnswer((_) async => 'txid-1');
      when(
        () => orders.markPayinBroadcast(
          localId: 'local-1',
          transactionId: 'txid-1',
        ),
      ).thenAnswer((_) async => Ok(broadcasted));
      bloc.emit(
        TransferState(
          orderSwap: prepared,
          signedPsbt: 'signed-psbt',
          fromWallet: _wallet(),
          swap: _swap(),
        ),
      );
      final states = <TransferState>[];
      final subscription = bloc.stream.listen(states.add);
      final completed = bloc.stream.firstWhere(
        (state) => state.txId == 'txid-1',
      );
      bloc.add(const TransferEvent.confirmed());
      await completed;
      await subscription.cancel();
      verify(() => orders.markBroadcastUnknown('local-1', requireReady: true))
          .called(1);
      verify(
        () => broadcastBitcoin.execute(
          'signed-psbt',
          isPsbt: true,
          network: BitcoinNetwork.testnet,
          walletId: 'wallet-1',
        ),
      ).called(1);
      verify(
        () => orders.markPayinBroadcast(
          localId: 'local-1',
          transactionId: 'txid-1',
        ),
      ).called(1);
      expect(bloc.state.txId, 'txid-1');
      expect(states.any((state) => state.txId == 'txid-1'), isTrue);
    },
  );

  test('Transfer MAX prices and builds from the selected UTXOs', () async {
    final selected = native.BitcoinCoin(
      outpoint: (txId: 'selected-tx', vout: 2),
      scriptPubkey: Uint8List(0),
      amountSat: BigInt.from(30000),
      address: 'tb1qselected',
      keychain: native.Keychain.external,
      confirmations: 0,
    );
    when(() => getReceiveAddress.receiveAddress(walletId: 'wallet-1'))
        .thenAnswer(
          (_) async => Ok(
            WalletAddress(
              walletId: 'wallet-1',
              index: 0,
              address: 'tb1qreceive',
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          ),
        );
    when(
      () => prepareBitcoin.execute(
        walletId: 'wallet-1',
        recipients: any(named: 'recipients'),
        networkFee: any(named: 'networkFee'),
        selectedInputs: [_legacyCoin(selected, 'wallet-1')],
        replaceByFee: true,
      ),
    ).thenAnswer(
      (_) async => Ok((
        unsignedPsbt: 'psbt',
        txSize: 100,
        isToSelf: false,
        recipientAmountsSat: [Sats.fromInt(28800)],
      )),
    );
    when(() => calculateBitcoin.execute(psbt: 'psbt'))
        .thenAnswer((_) async => 1200);
    bloc.emit(
      TransferState(
        fromWallet: _wallet(balanceSat: BigInt.from(130000)),
        bitcoinNetworkFees: _feeOptions(),
        selectedUtxos: [selected],
      ),
    );

    expect(
      await bloc.getMaxAmountSat(_wallet(balanceSat: BigInt.from(130000))),
      28800,
    );
    verify(
      () => prepareBitcoin.execute(
        walletId: 'wallet-1',
        recipients: any(named: 'recipients'),
        networkFee: any(named: 'networkFee'),
        selectedInputs: [_legacyCoin(selected, 'wallet-1')],
        replaceByFee: true,
      ),
    ).called(1);
  });

  test('coin selection recomputes an active Transfer MAX', () async {
    final selected = native.BitcoinCoin(
      outpoint: (txId: 'selected-tx', vout: 2),
      scriptPubkey: Uint8List(0),
      amountSat: BigInt.from(30000),
      address: 'tb1qselected',
      keychain: native.Keychain.external,
      confirmations: 0,
    );
    when(() => getReceiveAddress.receiveAddress(walletId: 'wallet-1'))
        .thenAnswer(
          (_) async => Ok(
            WalletAddress(
              walletId: 'wallet-1',
              index: 0,
              address: 'tb1qreceive',
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          ),
        );
    when(
      () => prepareBitcoin.execute(
        walletId: 'wallet-1',
        recipients: any(named: 'recipients'),
        networkFee: any(named: 'networkFee'),
        selectedInputs: [_legacyCoin(selected, 'wallet-1')],
        replaceByFee: true,
      ),
    ).thenAnswer(
      (_) async => Ok((
        unsignedPsbt: 'psbt',
        txSize: 100,
        isToSelf: false,
        recipientAmountsSat: [Sats.fromInt(28800)],
      )),
    );
    when(() => calculateBitcoin.execute(psbt: 'psbt'))
        .thenAnswer((_) async => 1200);
    bloc.emit(
      TransferState(
        fromWallet: _wallet(balanceSat: BigInt.from(130000)),
        toWallet: _liquidWallet(id: 'liquid-wallet'),
        bitcoinNetworkFees: _feeOptions(),
        receiveAddress: 'cached-destination',
        maxAmountSat: 128800,
        maxSelected: true,
        amount: '128800',
      ),
    );

    bloc.add(TransferEvent.utxosSelected([selected]));
    await bloc.stream.firstWhere((state) => state.maxAmountSat == 28800);

    expect(bloc.state.receiveAddress, 'cached-destination');
    expect(bloc.state.amount, '28800');
    expect(bloc.state.isMaxSelected, isTrue);
    expect(bloc.state.selectedUtxos, [selected]);
  });

  test(
    'Transfer MAX clamps a selected balance below the fee to zero',
    () async {
      final selected = native.BitcoinCoin(
        outpoint: (txId: 'selected-tx', vout: 2),
        scriptPubkey: Uint8List(0),
        amountSat: BigInt.from(1000),
        address: 'tb1qselected',
        keychain: native.Keychain.external,
        confirmations: 0,
      );
      when(() => getReceiveAddress.receiveAddress(walletId: 'wallet-1'))
          .thenAnswer(
            (_) async => Ok(
              WalletAddress(
                walletId: 'wallet-1',
                index: 0,
                address: 'tb1qreceive',
                createdAt: DateTime.utc(2026),
                updatedAt: DateTime.utc(2026),
              ),
            ),
          );
      when(
        () => prepareBitcoin.execute(
          walletId: 'wallet-1',
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          selectedInputs: [_legacyCoin(selected, 'wallet-1')],
          replaceByFee: true,
        ),
      ).thenAnswer(
        (_) async => Ok((
          unsignedPsbt: 'psbt',
          txSize: 100,
          isToSelf: false,
          recipientAmountsSat: [Sats.fromInt(0)],
        )),
      );
      when(() => calculateBitcoin.execute(psbt: 'psbt'))
          .thenAnswer((_) async => 1200);
      bloc.emit(
        TransferState(
          fromWallet: _wallet(balanceSat: BigInt.from(130000)),
          bitcoinNetworkFees: _feeOptions(),
          selectedUtxos: [selected],
        ),
      );

      expect(
        await bloc.getMaxAmountSat(_wallet(balanceSat: BigInt.from(130000))),
        0,
      );
    },
  );

  test(
    'a failed selection rebuild cannot broadcast the previous PSBT',
    () async {
      final oldSelection = native.BitcoinCoin(
        outpoint: (txId: 'old-selected-tx', vout: 0),
        scriptPubkey: Uint8List(0),
        amountSat: BigInt.from(30000),
        address: 'tb1qold',
        keychain: native.Keychain.external,
        confirmations: 0,
      );
      final unavailableSelection = native.BitcoinCoin(
        outpoint: (txId: 'unavailable-selected-tx', vout: 1),
        scriptPubkey: Uint8List(0),
        amountSat: BigInt.from(1000),
        address: 'tb1qunavailable',
        keychain: native.Keychain.external,
        confirmations: 0,
      );
      when(
        () => prepareBitcoin.execute(
          walletId: 'wallet-1',
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          selectedInputs: [_legacyCoin(unavailableSelection, 'wallet-1')],
          replaceByFee: true,
        ),
      ).thenThrow(InsufficientFundsException('selected coin unavailable'));
      bloc.emit(
        TransferState(
          fromWallet: _wallet(),
          toWallet: _destinationWallet(),
          receiveAddress: 'tb1qreceive',
          amount: '1000',
          bitcoinNetworkFees: _feeOptions(),
          selectedUtxos: [oldSelection],
          signedPsbt: 'old-signed-psbt',
        ),
      );

      bloc.add(TransferEvent.utxosSelected([unavailableSelection]));
      await pumpEventQueue();
      bloc.add(const TransferEvent.confirmed());
      await pumpEventQueue();

      expect(bloc.state.signedPsbt, isEmpty);
      expect(bloc.state.buildTransactionException, isNotNull);
      verifyNever(
        () => broadcastBitcoin.execute(
          'old-signed-psbt',
          isPsbt: true,
          network: BitcoinNetwork.testnet,
          walletId: 'wallet-1',
        ),
      );
    },
  );

  test('freezing a selected coin invalidates the staged PSBT', () async {
    final selected = native.BitcoinCoin(
      outpoint: (txId: 'selected-tx', vout: 2),
      scriptPubkey: Uint8List(0),
      amountSat: BigInt.from(30000),
      address: 'tb1qselected',
      keychain: native.Keychain.external,
      confirmations: 0,
    );
    final frozen = selected.withFrozen(true);
    when(() => getUtxos.execute(_wallet().key))
        .thenAnswer((_) async => Ok(native.CoinList([frozen])));
    bloc.emit(
      TransferState(
        fromWallet: _wallet(),
        selectedUtxos: [selected],
        utxos: [selected],
        signedPsbt: 'old-signed-psbt',
      ),
    );

    bloc.add(const TransferEvent.loadUtxos());
    await pumpEventQueue();

    expect(bloc.state.signedPsbt, isEmpty);
    expect(bloc.state.selectedUtxos, [selected]);
    expect(bloc.state.buildTransactionException, isNotNull);
  });

  test(
    'a newly reserved selected coin invalidates the cached PSBT before confirm',
    () async {
      final selected = native.BitcoinCoin(
        outpoint: (txId: 'selected-tx', vout: 2),
        scriptPubkey: Uint8List(0),
        amountSat: BigInt.from(30000),
        address: 'tb1qselected',
        keychain: native.Keychain.external,
        confirmations: 0,
      );
      when(
        () => validateBitcoinSelection.execute(
          walletId: 'wallet-1',
          selectedInputs: {selected.outpoint},
        ),
      ).thenAnswer(
        (_) async => const Err(SpendSelectedInputsUnavailableFailure()),
      );
      bloc.emit(
        TransferState(
          fromWallet: _wallet(),
          toWallet: _destinationWallet(),
          receiveAddress: 'tb1qreceive',
          amount: '1000',
          bitcoinNetworkFees: _feeOptions(),
          selectedUtxos: [selected],
          utxos: [selected],
          signedPsbt: 'old-signed-psbt',
          feePreviewCache: const BitcoinFeePreviewCache(
            fastest: BitcoinFeePreviewSlot(
              feeSat: 250,
              unsignedPsbt: 'old-unsigned-psbt',
              txSize: 100,
            ),
          ),
        ),
      );

      bloc.add(const TransferEvent.confirmed());
      await pumpEventQueue();

      expect(bloc.state.signedPsbt, isEmpty);
      expect(bloc.state.feePreviewCache.fastest.isCacheReady, isFalse);
      expect(bloc.state.buildTransactionException, isNotNull);
      verifyNever(
        () => broadcastBitcoin.execute(
          'old-signed-psbt',
          isPsbt: true,
          network: BitcoinNetwork.testnet,
          walletId: 'wallet-1',
        ),
      );
    },
  );

  test(
    'maps unavailable selected coins during confirm and clears fee previews',
    () async {
      final selected = _bitcoinUtxo('selected-tx');
      when(
        () => validateBitcoinSelection.execute(
          walletId: 'wallet-1',
          selectedInputs: {selected.outpoint},
        ),
      ).thenAnswer(
        (_) async => const Err(SpendSelectedInputsUnavailableFailure()),
      );
      bloc.emit(
        TransferState(
          fromWallet: _wallet(),
          toWallet: _destinationWallet(),
          receiveAddress: 'tb1qreceive',
          amount: '1000',
          selectedUtxos: [selected],
          signedPsbt: 'signed-psbt',
          feePreviewCache: const BitcoinFeePreviewCache(
            fastest: BitcoinFeePreviewSlot(
              feeSat: 250,
              unsignedPsbt: 'cached-unsigned-psbt',
              txSize: 100,
            ),
          ),
        ),
      );

      bloc.add(const TransferEvent.confirmed());
      await bloc.stream.firstWhere((state) => !state.isConfirming);

      expect(
        bloc.state.buildTransactionException?.message,
        selectedCoinsUnavailableCode,
      );
      expect(bloc.state.feePreviewCache.fastest.isCacheReady, isFalse);
      verifyNever(
        () => broadcastBitcoin.execute(
          any(),
          isPsbt: any(named: 'isPsbt'),
          network: BitcoinNetwork.testnet,
          walletId: 'wallet-1',
        ),
      );
    },
  );

  test('an in-flight old amount rebuild cannot repopulate signedPsbt after amountChanged', () async {
    final prepareStarted = Completer<void>();
    final prepareCompleter =
        Completer<Result<PreparedBitcoinSend, SendFailure>>();
    when(
      () => prepareBitcoin.execute(
        walletId: 'wallet-1',
        recipients: any(named: 'recipients'),
        networkFee: any(named: 'networkFee'),
        selectedInputs: any(named: 'selectedInputs'),
        replaceByFee: true,
      ),
    ).thenAnswer((_) {
      prepareStarted.complete();
      return prepareCompleter.future;
    });
    bloc.emit(
      TransferState(
        fromWallet: _wallet(),
        toWallet: _destinationWallet(),
        receiveAddress: 'tb1qreceive',
        amount: '1000',
        bitcoinNetworkFees: _feeOptions(),
        signedPsbt: 'previous-psbt',
      ),
    );

    bloc.add(const TransferEvent.feeOptionSelected(FeeSelection.economic));
    await prepareStarted.future;
    bloc.add(const TransferEvent.amountChanged('2000'));
    prepareCompleter.complete(
      Ok((
        unsignedPsbt: 'old-unsigned-psbt',
        txSize: 100,
        isToSelf: true,
        recipientAmountsSat: [Sats.fromInt(1000)],
      )),
    );
    await pumpEventQueue();

    expect(bloc.state.amount, '2000');
    expect(bloc.state.signedPsbt, isEmpty);
    verifyNever(
      () =>
          signBitcoin.execute(walletId: 'wallet-1', psbt: 'old-unsigned-psbt'),
    );
  });

  test('an in-flight swap creation cannot repopulate signedPsbt after amountChanged', () async {
    final prepareStarted = Completer<void>();
    final prepareCompleter =
        Completer<Result<PreparedBitcoinSend, SendFailure>>();
    when(
      () => prepareBitcoin.execute(
        walletId: 'wallet-1',
        recipients: any(named: 'recipients'),
        networkFee: any(named: 'networkFee'),
        selectedInputs: any(named: 'selectedInputs'),
        replaceByFee: true,
      ),
    ).thenAnswer((_) {
      prepareStarted.complete();
      return prepareCompleter.future;
    });
    when(
      () =>
          signBitcoin.execute(walletId: 'wallet-1', psbt: 'old-unsigned-psbt'),
    ).thenAnswer((_) async => (signedPsbt: 'old-signed-psbt', txSize: 100));
    when(() => calculateBitcoin.execute(psbt: 'old-signed-psbt'))
        .thenAnswer((_) async => 1200);
    bloc.emit(
      TransferState(
        fromWallet: _wallet(balanceSat: BigInt.from(100000)),
        toWallet: _destinationWallet(),
        receiveAddress: 'tb1qreceive',
        amount: '1000',
        bitcoinNetworkFees: _feeOptions(),
      ),
    );

    bloc.add(const TransferEvent.swapCreated('1000'));
    await prepareStarted.future;
    bloc.add(const TransferEvent.amountChanged('2000'));
    prepareCompleter.complete(
      Ok((
        unsignedPsbt: 'old-unsigned-psbt',
        txSize: 100,
        isToSelf: true,
        recipientAmountsSat: [Sats.fromInt(1000)],
      )),
    );
    await pumpEventQueue();

    expect(bloc.state.amount, '2000');
    expect(bloc.state.signedPsbt, isEmpty);
  });

  test('an in-flight swap creation cannot repopulate after destination wallet changes', () async {
    final prepareStarted = Completer<void>();
    final prepareCompleter =
        Completer<Result<PreparedBitcoinSend, SendFailure>>();
    final destination = _destinationWallet();
    final replacementDestination = _destinationWallet(id: 'wallet-3');
    when(
      () => prepareBitcoin.execute(
        walletId: 'wallet-1',
        recipients: any(named: 'recipients'),
        networkFee: any(named: 'networkFee'),
        selectedInputs: any(named: 'selectedInputs'),
        replaceByFee: true,
      ),
    ).thenAnswer((_) {
      prepareStarted.complete();
      return prepareCompleter.future;
    });
    bloc.emit(
      TransferState(
        fromWallet: _wallet(balanceSat: BigInt.from(100000)),
        toWallet: destination,
        receiveAddress: 'tb1qreceive',
        amount: '1000',
        bitcoinNetworkFees: _feeOptions(),
      ),
    );

    bloc.add(const TransferEvent.swapCreated('1000'));
    await prepareStarted.future;
    bloc.add(
      TransferEvent.walletsChanged(
        fromWallet: _wallet(balanceSat: BigInt.from(100000)),
        toWallet: replacementDestination,
      ),
    );
    prepareCompleter.complete(
      Ok((
        unsignedPsbt: 'old-unsigned-psbt',
        txSize: 100,
        isToSelf: true,
        recipientAmountsSat: [Sats.fromInt(1000)],
      )),
    );
    await pumpEventQueue();

    expect(bloc.state.toWallet, replacementDestination);
    expect(bloc.state.signedPsbt, isEmpty);
    expect(bloc.state.isCreatingSwap, isFalse);
    expect(bloc.state.continueClicked, isFalse);
    verifyNever(
      () =>
          signBitcoin.execute(walletId: 'wallet-1', psbt: 'old-unsigned-psbt'),
    );
  });

  test(
    'same selected outpoints do not invalidate in-flight swap creation',
    () async {
      final selected = _bitcoinUtxo('selected-tx');
      final prepareStarted = Completer<void>();
      final prepareCompleter =
          Completer<Result<PreparedBitcoinSend, SendFailure>>();
      when(
        () => prepareBitcoin.execute(
          walletId: 'wallet-1',
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          selectedInputs: [_legacyCoin(selected, 'wallet-1')],
          replaceByFee: true,
        ),
      ).thenAnswer((_) {
        prepareStarted.complete();
        return prepareCompleter.future;
      });
      when(
        () => signBitcoin.execute(walletId: 'wallet-1', psbt: 'unsigned-psbt'),
      ).thenAnswer((_) async => (signedPsbt: 'signed-psbt', txSize: 100));
      when(() => calculateBitcoin.execute(psbt: 'signed-psbt'))
          .thenAnswer((_) async => 1200);
      bloc.emit(
        TransferState(
          fromWallet: _wallet(balanceSat: BigInt.from(100000)),
          toWallet: _destinationWallet(),
          receiveAddress: 'tb1qreceive',
          amount: '1000',
          selectedUtxos: [selected],
          bitcoinNetworkFees: _feeOptions(),
        ),
      );

      bloc.add(const TransferEvent.swapCreated('1000'));
      await prepareStarted.future;
      bloc.add(TransferEvent.utxosSelected([selected]));
      prepareCompleter.complete(
        Ok((
          unsignedPsbt: 'unsigned-psbt',
          txSize: 100,
          isToSelf: true,
          recipientAmountsSat: [Sats.fromInt(1000)],
        )),
      );
      await bloc.stream.firstWhere(
        (state) => state.signedPsbt == 'signed-psbt',
      );

      expect(bloc.state.isCreatingSwap, isFalse);
      expect(bloc.state.signedPsbt, 'signed-psbt');
    },
  );

  test('send-to-external changes invalidate transaction work', () async {
    bloc.emit(
      TransferState(
        signedPsbt: 'stale-psbt',
        isCreatingSwap: true,
        continueClicked: true,
        receiveExactAmount: false,
      ),
    );

    bloc.add(const TransferEvent.sendToExternalToggled(true));
    await pumpEventQueue();

    expect(bloc.state.sendToExternal, isTrue);
    expect(bloc.state.receiveExactAmount, isTrue);
    expect(bloc.state.signedPsbt, isEmpty);
    expect(bloc.state.isCreatingSwap, isFalse);
    expect(bloc.state.continueClicked, isFalse);
  });

  test('send-to-external changes drop the receive address of the previous transfer', () async {
    bloc.emit(
      TransferState(
        fromWallet: _wallet(),
        toWallet: _destinationWallet(),
        sendToExternal: true,
        externalAddress: 'tb1qexternal',
        receiveAddress: 'tb1qexternal',
      ),
    );

    bloc.add(const TransferEvent.sendToExternalToggled(false));
    await pumpEventQueue();

    expect(bloc.state.sendToExternal, isFalse);
    expect(bloc.state.receiveAddress, isNull);
  });

  test('a same-chain transfer pays the current destination wallet, never a '
      'receive address left by an earlier transfer', () async {
    when(() => getReceiveAddress.receiveAddress(walletId: 'wallet-2'))
        .thenAnswer(
          (_) async => Ok(
            WalletAddress(
              walletId: 'wallet-2',
              index: 0,
              address: 'tb1qwallet2',
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          ),
        );
    when(
      () => prepareBitcoin.execute(
        walletId: 'wallet-1',
        recipients: any(named: 'recipients'),
        networkFee: any(named: 'networkFee'),
        selectedInputs: any(named: 'selectedInputs'),
        replaceByFee: true,
      ),
    ).thenAnswer(
      (_) async => Ok((
        unsignedPsbt: 'unsigned-psbt',
        txSize: 100,
        isToSelf: true,
        recipientAmountsSat: [Sats.fromInt(1000)],
      )),
    );
    when(() => signBitcoin.execute(walletId: 'wallet-1', psbt: 'unsigned-psbt'))
        .thenAnswer((_) async => (signedPsbt: 'signed-psbt', txSize: 100));
    when(() => calculateBitcoin.execute(psbt: 'signed-psbt'))
        .thenAnswer((_) async => 250);
    bloc.emit(
      TransferState(
        fromWallet: _wallet(balanceSat: BigInt.from(100000)),
        toWallet: _destinationWallet(),
        receiveAddress: 'tb1qexternal',
        bitcoinUnit: BitcoinUnit.sats,
        bitcoinNetworkFees: _feeOptions(),
      ),
    );

    bloc.add(const TransferEvent.swapCreated('1000'));
    await bloc.stream.firstWhere((state) => state.signedPsbt.isNotEmpty);

    final recipients =
        verify(
              () => prepareBitcoin.execute(
                walletId: 'wallet-1',
                recipients: captureAny(named: 'recipients'),
                networkFee: any(named: 'networkFee'),
                selectedInputs: any(named: 'selectedInputs'),
                replaceByFee: true,
              ),
            ).captured.single
            as List<BitcoinTransactionRecipient>;
    expect(recipients.single.address, 'tb1qwallet2');
    expect(bloc.state.receiveAddress, 'tb1qwallet2');
  });

  test('receive-exact-amount changes invalidate transaction work', () async {
    bloc.emit(
      TransferState(
        signedPsbt: 'stale-psbt',
        isCreatingSwap: true,
        continueClicked: true,
        receiveExactAmount: false,
      ),
    );

    bloc.add(const TransferEvent.receiveExactAmountToggled(true));
    await pumpEventQueue();

    expect(bloc.state.receiveExactAmount, isTrue);
    expect(bloc.state.signedPsbt, isEmpty);
    expect(bloc.state.isCreatingSwap, isFalse);
    expect(bloc.state.continueClicked, isFalse);
  });

  test(
    'contract changes detach a prepared swap before an RBF rebuild',
    () async {
      when(
        () => prepareBitcoin.execute(
          walletId: 'wallet-1',
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          selectedInputs: any(named: 'selectedInputs'),
          replaceByFee: false,
        ),
      ).thenAnswer(
        (_) async => Ok((
          unsignedPsbt: 'new-unsigned-psbt',
          txSize: 100,
          isToSelf: false,
          recipientAmountsSat: [Sats.fromInt(1000)],
        )),
      );
      when(
        () => verifyChain.execute(
          psbtOrPset: 'new-unsigned-psbt',
          swap: _swap(),
          wallet: _wallet().key,
        ),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => signBitcoin.execute(
          walletId: 'wallet-1',
          psbt: 'new-unsigned-psbt',
        ),
      ).thenAnswer((_) async => (signedPsbt: 'new-signed-psbt', txSize: 100));
      when(() => calculateBitcoin.execute(psbt: 'new-signed-psbt'))
          .thenAnswer((_) async => 1200);
      when(
        () => orders.replacePreparedPayin(
          localId: 'local-1',
          signedTransaction: 'new-signed-psbt',
          isPsbt: true,
        ),
      ).thenAnswer((_) async => Ok(prepared));
      bloc.emit(
        TransferState(
          fromWallet: _wallet(balanceSat: BigInt.from(100000)),
          toWallet: _liquidWallet(id: 'wallet-2'),
          swap: _swap(),
          orderSwap: prepared,
          amount: '1000',
          bitcoinNetworkFees: _feeOptions(),
          signedPsbt: 'old-signed-psbt',
        ),
      );

      bloc.add(const TransferEvent.amountChanged('2000'));
      await pumpEventQueue();

      bloc.add(const TransferEvent.replaceByFeeChanged(false));
      await pumpEventQueue();

      verifyNever(
        () => orders.replacePreparedPayin(
          localId: 'local-1',
          signedTransaction: 'new-signed-psbt',
          isPsbt: true,
        ),
      );
      expect(bloc.state.swap, isNull);
      expect(bloc.state.orderSwap, isNull);
    },
  );

  test('RBF rebuild preserves an unchanged prepared swap context', () async {
    when(
      () => prepareBitcoin.execute(
        walletId: 'wallet-1',
        recipients: any(named: 'recipients'),
        networkFee: any(named: 'networkFee'),
        selectedInputs: any(named: 'selectedInputs'),
        replaceByFee: false,
      ),
    ).thenAnswer(
      (_) async => Ok((
        unsignedPsbt: 'new-unsigned-psbt',
        txSize: 100,
        isToSelf: false,
        recipientAmountsSat: [Sats.fromInt(1000)],
      )),
    );
    when(
      () => verifyChain.execute(
        psbtOrPset: 'new-unsigned-psbt',
        swap: _swap(),
        wallet: _wallet().key,
      ),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () =>
          signBitcoin.execute(walletId: 'wallet-1', psbt: 'new-unsigned-psbt'),
    ).thenAnswer((_) async => (signedPsbt: 'new-signed-psbt', txSize: 100));
    when(() => calculateBitcoin.execute(psbt: 'new-signed-psbt'))
        .thenAnswer((_) async => 1200);
    when(
      () => orders.replacePreparedPayin(
        localId: 'local-1',
        signedTransaction: 'new-signed-psbt',
        isPsbt: true,
      ),
    ).thenAnswer((_) async => Ok(prepared));
    bloc.emit(
      TransferState(
        fromWallet: _wallet(balanceSat: BigInt.from(100000)),
        toWallet: _liquidWallet(id: 'wallet-2'),
        swap: _swap(),
        orderSwap: prepared,
        amount: '1000',
        bitcoinNetworkFees: _feeOptions(),
        signedPsbt: 'old-signed-psbt',
      ),
    );

    bloc.add(const TransferEvent.replaceByFeeChanged(false));
    await pumpEventQueue();

    verify(
      () => orders.replacePreparedPayin(
        localId: 'local-1',
        signedTransaction: 'new-signed-psbt',
        isPsbt: true,
      ),
    ).called(1);
    expect(bloc.state.orderSwap, prepared);
  });

  test('emits the transaction id before wallet sync completes', () async {
    final syncCompleter = Completer<SwapWallet>();
    final broadcasting = _prepared(
      status: OrderSwapLocalStatus.broadcastUnknown,
    );
    final broadcasted = _prepared(
      status: OrderSwapLocalStatus.payinBroadcast,
      transactionId: 'txid-1',
    );
    when(() => orders.markBroadcastUnknown('local-1', requireReady: true))
        .thenAnswer((_) async => Ok(broadcasting));
    when(
      () => broadcastBitcoin.execute(
        'signed-psbt',
        isPsbt: true,
        network: BitcoinNetwork.testnet,
        walletId: 'wallet-1',
      ),
    ).thenAnswer((_) async => 'txid-1');
    when(
      () => orders.markPayinBroadcast(
        localId: 'local-1',
        transactionId: 'txid-1',
      ),
    ).thenAnswer((_) async => Ok(broadcasted));
    bloc.emit(
      TransferState(
        orderSwap: prepared,
        signedPsbt: 'signed-psbt',
        fromWallet: _wallet(),
        swap: _swap(),
      ),
    );

    bloc.add(const TransferEvent.confirmed());
    await bloc.stream.firstWhere((state) => state.txId == 'txid-1');

    expect(syncCompleter.isCompleted, isFalse);
    expect(bloc.state.orderSwap, broadcasted);
    syncCompleter.complete(_wallet());
  });

  test('resumes a stored prepared transfer on start', () async {
    final settings = SettingsEntity(
      environment: Environment.testnet,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'USD',
    );
    when(() => getSettings.fetch()).thenAnswer((_) async => Ok(settings));
    when(() => orders.getPendingOrders())
        .thenAnswer((_) async => Ok([prepared]));
    when(() => getWallets.execute(any()))
        .thenAnswer((_) async => Ok([_liquidWallet(), _destinationWallet()]));
    when(() => getNetworkFees.estimate(any()))
        .thenAnswer((_) async => Ok(_feeOptions()));
    when(() => getExchangeRate.execute(currencyCode: 'USD'))
        .thenAnswer((_) async => const Ok(1.0));
    when(() => orders.watchOrder('local-1'))
        .thenAnswer((_) => const Stream.empty());

    bloc.add(const TransferEvent.started());
    await bloc.stream.firstWhere((state) => !state.isStarting);

    verify(() => getNetworkFees.estimate(BitcoinNetwork.testnet)).called(1);
    verify(() => getNetworkFees.estimate(LiquidNetwork.testnet)).called(1);

    expect(bloc.state.orderSwap, prepared);
    expect(bloc.state.signedPsbt, 'signed-psbt');
    expect(bloc.state.swap, isA<ChainSwap>());
  });

  test('resumes a stored transfer in the configured BTC unit', () async {
    final settings = SettingsEntity(
      environment: Environment.testnet,
      bitcoinUnit: BitcoinUnit.btc,
      currencyCode: 'USD',
    );
    when(() => getSettings.fetch()).thenAnswer((_) async => Ok(settings));
    when(() => orders.getPendingOrders())
        .thenAnswer((_) async => Ok([prepared]));
    when(() => getWallets.execute(any()))
        .thenAnswer((_) async => Ok([_liquidWallet(), _destinationWallet()]));
    when(() => getNetworkFees.estimate(any()))
        .thenAnswer((_) async => Ok(_feeOptions()));
    when(() => getExchangeRate.execute(currencyCode: 'USD'))
        .thenAnswer((_) async => const Ok(1.0));
    when(() => orders.watchOrder('local-1'))
        .thenAnswer((_) => const Stream.empty());

    bloc.add(const TransferEvent.started());
    await bloc.stream.firstWhere((state) => !state.isStarting);

    expect(bloc.state.amount, '0.00001');
    expect(bloc.state.inputAmountSat, 1000);
  });

  test('starts without a price: no rate and no start error', () async {
    final settings = SettingsEntity(
      environment: Environment.testnet,
      bitcoinUnit: BitcoinUnit.btc,
      currencyCode: 'USD',
    );
    when(() => getSettings.fetch()).thenAnswer((_) async => Ok(settings));
    when(() => orders.getPendingOrders())
        .thenAnswer((_) async => Ok([prepared]));
    when(() => getWallets.execute(any()))
        .thenAnswer((_) async => Ok([_liquidWallet(), _destinationWallet()]));
    when(() => getNetworkFees.estimate(any()))
        .thenAnswer((_) async => Ok(_feeOptions()));
    when(() => getExchangeRate.execute(currencyCode: 'USD'))
        .thenAnswer((_) async => const Err(SwapPriceUnavailableFailure()));
    when(() => orders.watchOrder('local-1'))
        .thenAnswer((_) => const Stream.empty());

    bloc.add(const TransferEvent.started());
    await bloc.stream.firstWhere((state) => !state.isStarting);

    expect(bloc.state.exchangeRate, isNull);
    expect(bloc.state.startError, isNull);
    expect(bloc.state.inputAmountSat, 1000);
  });

  test('a failure other than no price stops the start', () async {
    final settings = SettingsEntity(
      environment: Environment.testnet,
      bitcoinUnit: BitcoinUnit.btc,
      currencyCode: 'USD',
    );
    when(() => getSettings.fetch()).thenAnswer((_) async => Ok(settings));
    when(() => orders.getPendingOrders())
        .thenAnswer((_) async => Ok([prepared]));
    when(() => getWallets.execute(any()))
        .thenAnswer((_) async => Ok([_liquidWallet(), _destinationWallet()]));
    when(() => getNetworkFees.estimate(any()))
        .thenAnswer((_) async => Ok(_feeOptions()));
    when(() => getExchangeRate.execute(currencyCode: 'USD'))
        .thenAnswer((_) async => const Err(SwapUnexpectedFailure('settings')));
    when(() => orders.watchOrder('local-1'))
        .thenAnswer((_) => const Stream.empty());

    bloc.add(const TransferEvent.started());
    await bloc.stream.firstWhere((state) => !state.isStarting);

    expect(bloc.state.exchangeRate, isNull);
    expect(bloc.state.startError, isNotNull);
  });

  test('resumes the persisted non-default wallet pair', () async {
    when(() => getSettings.fetch()).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.testnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      ),
    );
    when(() => orders.getPendingOrders())
        .thenAnswer((_) async => Ok([prepared]));
    when(() => getWallets.execute(any())).thenAnswer(
      (_) async => Ok<List<SwapWallet>, SwapFailure>([
        _liquidWallet(id: 'default-liquid', isDefault: true),
        _liquidWallet(),
        _destinationWallet(id: 'default-bitcoin', isDefault: true),
        _destinationWallet(),
      ]),
    );
    when(() => getNetworkFees.estimate(any()))
        .thenAnswer((_) async => Ok(_feeOptions()));
    when(() => getExchangeRate.execute(currencyCode: 'USD'))
        .thenAnswer((_) async => const Ok(1.0));
    when(() => orders.watchOrder('local-1'))
        .thenAnswer((_) => const Stream.empty());

    bloc.add(const TransferEvent.started());
    await bloc.stream.firstWhere((state) => !state.isStarting);

    expect(bloc.state.fromWallet?.id, 'wallet-1');
    expect(bloc.state.toWallet?.id, 'wallet-2');
    expect(bloc.state.orderSwap?.localId, 'local-1');
  });

  test('surfaces a typed failure from the order watcher', () async {
    when(() => getSettings.fetch()).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.testnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      ),
    );
    when(() => orders.getPendingOrders())
        .thenAnswer((_) async => Ok([prepared]));
    when(() => getWallets.execute(any()))
        .thenAnswer((_) async => Ok([_liquidWallet(), _destinationWallet()]));
    when(() => getNetworkFees.estimate(any()))
        .thenAnswer((_) async => Ok(_feeOptions()));
    when(() => getExchangeRate.execute(currencyCode: 'USD'))
        .thenAnswer((_) async => const Ok(1.0));
    when(() => orders.watchOrder('local-1')).thenAnswer(
      (_) =>
          Stream.value(const Err(SwapStorageFailure('database unavailable'))),
    );

    bloc.add(const TransferEvent.started());
    await bloc.stream.firstWhere((state) => state.swapFailure != null);

    expect(bloc.state.swapFailure, isA<SwapStorageFailure>());
  });

  test(
    'refreshes an unknown broadcast and skips rebroadcast when payin is seen',
    () async {
      final unknown = _prepared(status: OrderSwapLocalStatus.broadcastUnknown);
      final refreshed = _prepared(
        status: OrderSwapLocalStatus.payoutInProgress,
        payinStatus: 'Completed',
      );
      when(() => orders.refreshOrder('local-1'))
          .thenAnswer((_) async => Ok(refreshed));
      bloc.emit(
        TransferState(
          orderSwap: unknown,
          signedPsbt: 'signed-psbt',
          fromWallet: _wallet(),
          swap: _swap(),
        ),
      );

      bloc.add(const TransferEvent.confirmed());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verify(() => orders.refreshOrder('local-1')).called(1);
      verifyNever(
        () => orders.markBroadcastUnknown(
          any(),
          requireReady: any(named: 'requireReady'),
        ),
      );
      verifyNever(
        () => broadcastBitcoin.execute(
          any(),
          isPsbt: any(named: 'isPsbt'),
          network: BitcoinNetwork.testnet,
          walletId: 'wallet-1',
        ),
      );
      expect(bloc.state.orderSwap, refreshed);
    },
  );

  test(
    'surfaces an expired stored transfer without a broadcast transaction',
    () async {
      final expired = _prepared(
        order: _order(deadline: DateTime.utc(2026, 1, 1, 0, 5)),
      );
      when(() => getSettings.fetch()).thenAnswer(
        (_) async => Ok(
          const SettingsEntity(
            environment: Environment.testnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
          ),
        ),
      );
      when(() => orders.getPendingOrders())
          .thenAnswer((_) async => Ok([expired]));
      when(() => getWallets.execute(any()))
          .thenAnswer((_) async => Ok([_liquidWallet(), _destinationWallet()]));
      when(() => getNetworkFees.estimate(any()))
          .thenAnswer((_) async => Ok(_feeOptions()));
      when(() => getExchangeRate.execute(currencyCode: 'USD'))
          .thenAnswer((_) async => const Ok(1.0));

      bloc.add(const TransferEvent.started());
      await bloc.stream.firstWhere((state) => !state.isStarting);

      expect(bloc.state.orderSwap, expired);
      expect(bloc.state.swap?.status, SwapStatus.expired);
      expect(bloc.state.signedPsbt, isEmpty);
      bloc.add(const TransferEvent.confirmed());
      await Future<void>.delayed(Duration.zero);
      verifyNever(
        () => broadcastBitcoin.execute(
          any(),
          isPsbt: any(named: 'isPsbt'),
          network: BitcoinNetwork.testnet,
          walletId: 'wallet-1',
        ),
      );
    },
  );

  test(
    'surfaces a broadcast network failure without raw exception text',
    () async {
      when(() => orders.markBroadcastUnknown('local-1', requireReady: true))
          .thenAnswer((_) async => Ok(prepared));
      when(
        () => broadcastBitcoin.execute(
          'signed-psbt',
          isPsbt: true,
          network: BitcoinNetwork.testnet,
          walletId: 'wallet-1',
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/broadcast'),
          message: 'broadcast failed',
        ),
      );
      bloc.emit(
        TransferState(
          orderSwap: prepared,
          signedPsbt: 'signed-psbt',
          fromWallet: _wallet(),
          swap: _swap(),
        ),
      );
      bloc.add(const TransferEvent.confirmed());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.swapFailure, isA<SwapNetworkFailure>());
      expect(bloc.state.confirmTransactionException, isNull);
      expect(bloc.state.swapFailure!.logMessage, isNull);
    },
  );

  test('preserves a typed swap failure while confirming', () async {
    when(() => orders.markBroadcastUnknown('local-1', requireReady: true))
        .thenAnswer((_) async => const Err(SwapOrderExpiredFailure('expired')));
    bloc.emit(
      TransferState(
        orderSwap: prepared,
        signedPsbt: 'signed-psbt',
        fromWallet: _wallet(),
        swap: _swap(),
      ),
    );

    bloc.add(const TransferEvent.confirmed());
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.swapFailure, isA<SwapOrderExpiredFailure>());
  });

  group('Boltz-first transfers', () {
    group('regtest MAX lockup estimates', () {
      setUpAll(() => BullSdk.init());
      tearDownAll(BullSdk.dispose);
      for (final isLiquid in [false, true]) {
        for (final selectedOnly in [false, true]) {
          test(
            'regtest MAX prices a concrete Taproot lockup on ${isLiquid ? 'Liquid' : 'Bitcoin'} selected=$selectedOnly',
            () async {
              final source = (isLiquid ? _liquidWallet() : _wallet()).copyWith(
                network: isLiquid
                    ? LiquidNetwork.regtest
                    : BitcoinNetwork.regtest,
                balanceSat: BigInt.from(100000),
              );
              final destination =
                  (isLiquid
                          ? _destinationWallet()
                          : _liquidWallet(id: 'wallet-2'))
                      .copyWith(
                        network: isLiquid
                            ? BitcoinNetwork.regtest
                            : LiquidNetwork.regtest,
                      );
              when(() => getSwapRoute.execute())
                  .thenAnswer((_) async => SwapRoute.boltz);
              final selected = isLiquid
                  ? native.LiquidCoin(
                      outpoint: (txId: 'fixture-selected', vout: 0),
                      scriptPubkey: '',
                      amountSat: BigInt.from(30000),
                      standardAddress: 'ert1fixture',
                      confidentialAddress: 'el1fixture',
                      blockHeight: null,
                    )
                  : native.BitcoinCoin(
                      outpoint: (txId: 'fixture-selected', vout: 0),
                      scriptPubkey: Uint8List(0),
                      amountSat: BigInt.from(30000),
                      address: 'bcrt1fixture',
                      keychain: native.Keychain.external,
                      confirmations: 0,
                    );
              final priced = <String>[];
              when(
                () => prepareBitcoin.execute(
                  walletId: source.id,
                  recipients: any(named: 'recipients'),
                  networkFee: any(named: 'networkFee'),
                  selectedInputs: any(named: 'selectedInputs'),
                ),
              ).thenAnswer((invocation) async {
                final recipients =
                    invocation.namedArguments[#recipients]
                        as List<BitcoinTransactionRecipient>;
                priced.add(recipients.single.address);
                return Ok((
                  unsignedPsbt: 'max-regtest',
                  txSize: 120,
                  isToSelf: false,
                  recipientAmountsSat: <Sats>[],
                ));
              });
              when(() => calculateBitcoin.execute(psbt: 'max-regtest'))
                  .thenAnswer((_) async => 500);
              when(
                () => prepareLiquid.execute(
                  walletId: source.id,
                  address: any(named: 'address'),
                  feeRate: any(named: 'feeRate'),
                  drain: true,
                ),
              ).thenAnswer((invocation) async {
                priced.add(invocation.namedArguments[#address] as String);
                return const Ok('max-regtest');
              });
              when(() => calculateLiquid.execute(pset: 'max-regtest'))
                  .thenAnswer((_) async => 500);
              when(
                () => createBitcoinToLiquid.execute(
                  sendWalletId: source.id,
                  amountSat: any(named: 'amountSat'),
                  destination: any(named: 'destination'),
                ),
              ).thenAnswer(
                (_) async => const Err(SwapsBoltzRejectedFailure('fixture')),
              );
              when(
                () => createLiquidToBitcoin.execute(
                  sendWalletId: source.id,
                  amountSat: any(named: 'amountSat'),
                  destination: any(named: 'destination'),
                ),
              ).thenAnswer(
                (_) async => const Err(SwapsBoltzRejectedFailure('fixture')),
              );
              bloc.emit(
                TransferState(
                  fromWallet: source,
                  toWallet: destination,
                  bitcoinUnit: BitcoinUnit.sats,
                  maxAmountSat: selectedOnly ? 29000 : 99000,
                  maxSelected: true,
                  selectedUtxos: selectedOnly ? [selected] : [],
                  bitcoinNetworkFees: _feeOptions(),
                  liquidNetworkFees: _feeOptions(),
                  receiveExactAmount: false,
                ),
              );
              bloc.add(
                TransferEvent.swapCreated(selectedOnly ? '29000' : '99000'),
              );
              await bloc.stream.firstWhere((state) => !state.isCreatingSwap);
              expect(
                priced,
                hasLength(1),
                reason: 'Regtest MAX must reach concrete lockup preparation rather than return null',
              );
              expect(priced.single, startsWith(isLiquid ? 'el1p' : 'bcrt1p'));
              expect(
                priced.single.length,
                isLiquid ? 120 : 64,
                reason:
                    '32-byte Taproot witness program, confidential on Liquid',
              );
              expect(
                await native.validateAddress(
                  priced.single,
                  isLiquid ? LiquidNetwork.regtest : BitcoinNetwork.regtest,
                ),
                isA<Ok>(),
              );
              if (isLiquid) {
                verify(
                  () => createLiquidToBitcoin.execute(
                    sendWalletId: source.id,
                    amountSat: selectedOnly ? 29500 : 99500,
                    destination: any(named: 'destination'),
                  ),
                ).called(1);
              } else {
                verify(
                  () => createBitcoinToLiquid.execute(
                    sendWalletId: source.id,
                    amountSat: selectedOnly ? 29500 : 99500,
                    destination: any(named: 'destination'),
                  ),
                ).called(1);
              }
            },
          );
        }
      }

      for (final isLiquid in [false, true]) {
        test(
          'regtest MAX refuses insufficient known balance on ${isLiquid ? 'Liquid' : 'Bitcoin'}',
          () async {
            final source = (isLiquid ? _liquidWallet() : _wallet()).copyWith(
              network: isLiquid
                  ? LiquidNetwork.regtest
                  : BitcoinNetwork.regtest,
              balanceSat: BigInt.from(500),
            );
            final destination =
                (isLiquid
                        ? _destinationWallet()
                        : _liquidWallet(id: 'wallet-2'))
                    .copyWith(
                      network: isLiquid
                          ? BitcoinNetwork.regtest
                          : LiquidNetwork.regtest,
                    );
            bloc.emit(
              TransferState(
                fromWallet: source,
                toWallet: destination,
                bitcoinUnit: BitcoinUnit.sats,
                maxAmountSat: 99000,
                maxSelected: true,
                bitcoinNetworkFees: _feeOptions(),
                liquidNetworkFees: _feeOptions(),
                receiveExactAmount: false,
              ),
            );
            bloc.add(const TransferEvent.swapCreated('99000'));
            await bloc.stream.firstWhere((state) => !state.isCreatingSwap);
            verifyZeroInteractions(prepareBitcoin);
            verifyZeroInteractions(prepareLiquid);
            verifyZeroInteractions(createBitcoinToLiquid);
            verifyZeroInteractions(createLiquidToBitcoin);
          },
        );
      }
    });

    TransferState crossChain({bool receiveExactAmount = false}) =>
        TransferState(
          fromWallet: _wallet(balanceSat: BigInt.from(100000)),
          toWallet: _liquidWallet(id: 'wallet-2'),
          bitcoinUnit: BitcoinUnit.sats,
          bitcoinNetworkFees: _feeOptions(),
          receiveExactAmount: receiveExactAmount,
        );

    void stubCreateChain(Result<ChainSwap, SwapsFailure> result) => when(
      () => createBitcoinToLiquid.execute(
        sendWalletId: 'wallet-1',
        amountSat: any(named: 'amountSat'),
        destination: any(named: 'destination', that: _toWallet('wallet-2')),
      ),
    ).thenAnswer((_) async => result);

    void stubLockupBuild() {
      when(
        () => prepareBitcoin.execute(
          walletId: 'wallet-1',
          recipients: any(
            named: 'recipients',
            that: _paysTo('payin-address', amountSat: 1000),
          ),
          networkFee: any(named: 'networkFee'),
          replaceByFee: true,
        ),
      ).thenAnswer(
        (_) async => Ok((
          unsignedPsbt: 'lockup-unsigned',
          txSize: 100,
          isToSelf: false,
          recipientAmountsSat: [Sats.fromInt(1000)],
        )),
      );
      when(
        () => verifyChain.execute(
          psbtOrPset: 'lockup-unsigned',
          swap: _swap(),
          wallet: _wallet().key,
        ),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () =>
            signBitcoin.execute(walletId: 'wallet-1', psbt: 'lockup-unsigned'),
      ).thenAnswer((_) async => (signedPsbt: 'lockup-signed', txSize: 100));
      when(() => calculateBitcoin.execute(psbt: 'lockup-unsigned'))
          .thenAnswer((_) async => 1200);
    }

    test('creates a Boltz chain swap and signs its verified lockup', () async {
      when(() => getSwapRoute.execute())
          .thenAnswer((_) async => SwapRoute.boltz);
      stubCreateChain(Ok(_swap()));
      stubLockupBuild();
      bloc.emit(crossChain());

      bloc.add(const TransferEvent.swapCreated('1000'));
      await bloc.stream.firstWhere((state) => !state.isCreatingSwap);

      expect(bloc.state.swap?.id, 'swap-1');
      expect(bloc.state.bitcoinAbsoluteFeesSat, 1200);
      expect(bloc.state.orderSwap, isNull);
      expect(bloc.state.signedPsbt, 'lockup-signed');
      verify(
        () => verifyChain.execute(
          psbtOrPset: 'lockup-unsigned',
          swap: _swap(),
          wallet: _wallet().key,
        ),
      ).called(1);
      verify(() => watchSwap.execute('swap-1')).called(1);
      verifyNever(
        () => orders.getQuote(
          environment: any(named: 'environment'),
          amountSat: any(named: 'amountSat'),
          isInAmountFixed: any(named: 'isInAmountFixed'),
          inNetwork: any(named: 'inNetwork'),
          outNetwork: any(named: 'outNetwork'),
        ),
      );
    });

    group('Payjoin reservations (network switched without a relaunch)', () {
      void stubReservations({required bool readable}) {
        final stub = when(
          () => validateBitcoinSelection.execute(walletId: 'wallet-1'),
        );
        if (readable) {
          stub.thenAnswer((_) async => const Ok(null));
        } else {
          stub.thenAnswer((_) async => const Err(SpendUnavailableFailure()));
        }
      }

      test(
        'unreadable reservations create no swap and ask for a relaunch',
        () async {
          when(() => getSwapRoute.execute())
              .thenAnswer((_) async => SwapRoute.boltz);
          stubReservations(readable: false);
          bloc.emit(crossChain());

          bloc.add(const TransferEvent.swapCreated('1000'));
          await bloc.stream.firstWhere((state) => state.swapFailure != null);

          expect(bloc.state.swapFailure, isA<SwapRelaunchRequiredFailure>());
          expect(bloc.state.swap, isNull);
          verifyNever(
            () => createBitcoinToLiquid.execute(
              sendWalletId: any(named: 'sendWalletId'),
              amountSat: any(named: 'amountSat'),
              destination: any(named: 'destination'),
            ),
          );
        },
      );

      test('after a relaunch the swap proceeds', () async {
        when(() => getSwapRoute.execute())
            .thenAnswer((_) async => SwapRoute.boltz);
        stubReservations(readable: true);
        stubCreateChain(Ok(_swap()));
        stubLockupBuild();
        bloc.emit(crossChain());

        bloc.add(const TransferEvent.swapCreated('1000'));
        await bloc.stream.firstWhere((state) => !state.isCreatingSwap);

        expect(bloc.state.swapFailure, isNull);
        expect(bloc.state.swap?.id, 'swap-1');
      });
    });

    group('from a Liquid wallet that must consolidate', () {
      TransferState fromLiquid({bool consolidationRequired = false}) =>
          TransferState(
            fromWallet: _liquidWallet().copyWith(
              balanceSat: BigInt.from(100000),
            ),
            toWallet: _wallet().copyWith(origin: 'wallet-2'),
            bitcoinUnit: BitcoinUnit.sats,
            liquidNetworkFees: _feeOptions(),
            receiveExactAmount: false,
            consolidationRequired: consolidationRequired,
          );

      setUp(() {
        when(() => getSwapRoute.execute())
            .thenAnswer((_) async => SwapRoute.boltz);
      });

      test('a known consolidation need creates no swap', () async {
        bloc.emit(fromLiquid(consolidationRequired: true));

        bloc.add(const TransferEvent.swapCreated('1000'));
        await bloc.stream.firstWhere((state) => !state.isCreatingSwap);

        expect(bloc.state.consolidationRequired, isTrue);
        expect(bloc.state.swap, isNull);
        verifyNever(
          () => createBitcoinToLiquid.execute(
            sendWalletId: any(named: 'sendWalletId'),
            amountSat: any(named: 'amountSat'),
            destination: any(named: 'destination'),
          ),
        );
        verifyNever(
          () => createLiquidToBitcoin.execute(
            sendWalletId: any(named: 'sendWalletId'),
            amountSat: any(named: 'amountSat'),
            destination: any(named: 'destination'),
          ),
        );
      });

      test('a lockup build that needs consolidation says so', () async {
        when(
          () => createLiquidToBitcoin.execute(
            sendWalletId: any(named: 'sendWalletId'),
            amountSat: any(named: 'amountSat'),
            destination: any(named: 'destination'),
          ),
        ).thenAnswer((_) async => Ok(_swap()));
        when(
          () => prepareLiquid.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
            amountSat: any(named: 'amountSat'),
            feeRate: any(named: 'feeRate'),
            drain: any(named: 'drain'),
          ),
        ).thenAnswer(
          (_) async => const Err(SpendConsolidationRequiredFailure()),
        );
        bloc.emit(fromLiquid());

        bloc.add(const TransferEvent.swapCreated('1000'));
        await bloc.stream.firstWhere((state) => !state.isCreatingSwap);

        expect(bloc.state.consolidationRequired, isTrue);
        expect(bloc.state.signedPsbt, isEmpty);
      });
    });

    group('to an external address', () {
      TransferState external({SwapFailure? error}) => crossChain().copyWith(
        sendToExternal: true,
        externalAddress: 'destination',
        externalAddressError: error,
      );

      void stubDetected(PaymentRequest request) => when(
        () => detectBitcoin.execute(
          data: 'destination',
          environment: any(named: 'environment'),
        ),
      ).thenAnswer((_) async => request);

      void verifyNoSwap() {
        verifyNever(
          () => createBitcoinToLiquid.execute(
            sendWalletId: any(named: 'sendWalletId'),
            amountSat: any(named: 'amountSat'),
            destination: any(named: 'destination'),
          ),
        );
        verifyNever(
          () => createLiquidToBitcoin.execute(
            sendWalletId: any(named: 'sendWalletId'),
            amountSat: any(named: 'amountSat'),
            destination: any(named: 'destination'),
          ),
        );
      }

      setUp(() {
        when(() => getSwapRoute.execute())
            .thenAnswer((_) async => SwapRoute.boltz);
      });

      test('an address the screen flagged never gets a swap', () async {
        stubDetected(
          const PaymentRequest.liquid(address: 'destination', isTestnet: true),
        );
        bloc.emit(
          external(
            error: const SwapInvalidExternalAddressFailure(
              expectsBitcoin: false,
            ),
          ),
        );

        bloc.add(const TransferEvent.swapCreated('1000'));
        await bloc.stream.firstWhere((state) => !state.isCreatingSwap);

        expect(bloc.state.swap, isNull);
        verifyNoSwap();
      });

      test('an address on the source chain never gets a swap', () async {
        stubDetected(
          const PaymentRequest.bitcoin(address: 'destination', isTestnet: true),
        );
        bloc.emit(external());

        bloc.add(const TransferEvent.swapCreated('1000'));
        await bloc.stream.firstWhere((state) => !state.isCreatingSwap);

        expect(bloc.state.swap, isNull);
        verifyNoSwap();
      });

      test('an address on the other network never gets a swap', () async {
        stubDetected(
          const PaymentRequest.liquid(address: 'destination', isTestnet: false),
        );
        bloc.emit(external());

        bloc.add(const TransferEvent.swapCreated('1000'));
        await bloc.stream.firstWhere((state) => !state.isCreatingSwap);

        expect(bloc.state.swap, isNull);
        verifyNoSwap();
      });

      test('a destination-chain address creates the swap to it', () async {
        stubDetected(
          const PaymentRequest.liquid(address: 'destination', isTestnet: true),
        );
        when(
          () => createBitcoinToLiquid.execute(
            sendWalletId: 'wallet-1',
            amountSat: any(named: 'amountSat'),
            destination: any(
              named: 'destination',
              that: _toAddress('destination'),
            ),
          ),
        ).thenAnswer((_) async => const Err(SwapsBoltzRejectedFailure('x')));
        bloc.emit(external());

        bloc.add(const TransferEvent.swapCreated('1000'));
        await bloc.stream.firstWhere((state) => !state.isCreatingSwap);

        verify(
          () => createBitcoinToLiquid.execute(
            sendWalletId: 'wallet-1',
            amountSat: any(named: 'amountSat'),
            destination: any(
              named: 'destination',
              that: _toAddress('destination'),
            ),
          ),
        ).called(1);
      });
    });

    test('Boltz unavailable without the opt-in surfaces a failure', () async {
      when(() => getSwapRoute.execute())
          .thenAnswer((_) async => SwapRoute.boltz);
      stubCreateChain(const Err(SwapsBoltzUnavailableFailure()));
      bloc.emit(crossChain());

      bloc.add(const TransferEvent.swapCreated('1000'));
      await bloc.stream.firstWhere((state) => !state.isCreatingSwap);

      expect(bloc.state.swapFailure, isA<SwapNetworkFailure>());
      verifyNever(
        () => orders.getQuote(
          environment: any(named: 'environment'),
          amountSat: any(named: 'amountSat'),
          isInAmountFixed: any(named: 'isInAmountFixed'),
          inNetwork: any(named: 'inNetwork'),
          outNetwork: any(named: 'outNetwork'),
        ),
      );
    });

    test('falls back to the exchange when the user opted in', () async {
      when(() => getSwapRoute.execute())
          .thenAnswer((_) async => SwapRoute.boltzWithExchangeFallback);
      stubCreateChain(
        const Err(
          SwapsAmountOutOfLimitsFailure(minSat: 25000, maxSat: 1000000),
        ),
      );
      when(
        () =>
            getReceiveAddress.receiveAddress(walletId: any(named: 'walletId')),
      ).thenAnswer(
        (_) async => Ok(
          WalletAddress(
            walletId: 'wallet-2',
            index: 0,
            address: 'lq1destination',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        ),
      );
      when(
        () => orders.getQuote(
          environment: any(named: 'environment'),
          amountSat: any(named: 'amountSat'),
          isInAmountFixed: any(named: 'isInAmountFixed'),
          inNetwork: any(named: 'inNetwork'),
          outNetwork: any(named: 'outNetwork'),
        ),
      ).thenAnswer((_) async => const Err(SwapNetworkFailure()));
      bloc.emit(crossChain());

      bloc.add(const TransferEvent.swapCreated('1000'));
      await bloc.stream.firstWhere((state) => !state.isCreatingSwap);

      verify(
        () => orders.getQuote(
          environment: any(named: 'environment'),
          amountSat: any(named: 'amountSat'),
          isInAmountFixed: any(named: 'isInAmountFixed'),
          inNetwork: any(named: 'inNetwork'),
          outNetwork: any(named: 'outNetwork'),
        ),
      ).called(1);
    });

    test('a Boltz refusal never falls back', () async {
      when(() => getSwapRoute.execute())
          .thenAnswer((_) async => SwapRoute.boltzWithExchangeFallback);
      stubCreateChain(const Err(SwapsBoltzRejectedFailure()));
      bloc.emit(crossChain());

      bloc.add(const TransferEvent.swapCreated('1000'));
      await bloc.stream.firstWhere((state) => !state.isCreatingSwap);

      expect(bloc.state.swapFailure, isA<SwapProviderFailure>());
      verifyNever(
        () => orders.getQuote(
          environment: any(named: 'environment'),
          amountSat: any(named: 'amountSat'),
          isInAmountFixed: any(named: 'isInAmountFixed'),
          inNetwork: any(named: 'inNetwork'),
          outNetwork: any(named: 'outNetwork'),
        ),
      );
    });

    test('exact receive pays the amount plus Boltz fees', () async {
      when(() => getSwapRoute.execute())
          .thenAnswer((_) async => SwapRoute.boltz);
      when(() => getLimitsAndFees.execute(SwapType.bitcoinToLiquid)).thenAnswer(
        (_) async => const Ok((
          SwapLimits(min: 100, max: 1000000),
          SwapFees(boltzPercent: 0.1, lockupFee: 100, claimFee: 50),
        )),
      );
      stubCreateChain(const Err(SwapsBoltzRejectedFailure()));
      bloc.emit(crossChain(receiveExactAmount: true));

      bloc.add(const TransferEvent.swapCreated('1000'));
      await bloc.stream.firstWhere((state) => !state.isCreatingSwap);

      final paid =
          verify(
                () => createBitcoinToLiquid.execute(
                  sendWalletId: 'wallet-1',
                  amountSat: captureAny(named: 'amountSat'),
                  destination: any(
                    named: 'destination',
                    that: _toWallet('wallet-2'),
                  ),
                ),
              ).captured.single
              as int;
      expect(paid, greaterThan(1000));
    });

    test('a max transfer is priced against a Taproot lockup', () async {
      when(() => getSwapRoute.execute())
          .thenAnswer((_) async => SwapRoute.boltz);
      when(
        () => prepareBitcoin.execute(
          walletId: 'wallet-1',
          recipients: any(
            named: 'recipients',
            that: _paysTo(
              'tb1p0e9sutev5p0whwkdqdzy6gw03m6g66zuullc4erh80u7qezneskqjfymf6',
            ),
          ),
          networkFee: any(named: 'networkFee'),
          selectedInputs: any(named: 'selectedInputs'),
        ),
      ).thenAnswer(
        (_) async => Ok((
          unsignedPsbt: 'max-psbt',
          txSize: 120,
          isToSelf: false,
          recipientAmountsSat: const <Sats>[],
        )),
      );
      when(() => calculateBitcoin.execute(psbt: 'max-psbt'))
          .thenAnswer((_) async => 500);
      stubCreateChain(const Err(SwapsBoltzRejectedFailure()));
      bloc.emit(crossChain().copyWith(maxAmountSat: 99000, maxSelected: true));

      bloc.add(const TransferEvent.swapCreated('99000'));
      await bloc.stream.firstWhere((state) => !state.isCreatingSwap);

      final paid =
          verify(
                () => createBitcoinToLiquid.execute(
                  sendWalletId: 'wallet-1',
                  amountSat: captureAny(named: 'amountSat'),
                  destination: any(
                    named: 'destination',
                    that: _toWallet('wallet-2'),
                  ),
                ),
              ).captured.single
              as int;
      expect(paid, 99500);
    });

    test(
      'a stale exchange order update never attaches to a Boltz swap',
      () async {
        bloc.emit(
          crossChain().copyWith(swap: _swap(), signedPsbt: 'lockup-signed'),
        );

        bloc.add(TransferEvent.orderSwapUpdated(Ok(prepared)));
        await pumpEventQueue();

        expect(bloc.state.orderSwap, isNull);
        expect(bloc.state.swap?.sendTxid, isNull);
      },
    );

    test('confirm broadcasts the lockup and records it on the swap', () async {
      final funded = _swap().copyWith(
        status: SwapStatus.paid,
        sendTxid: 'lockup-txid',
      );
      when(
        () => broadcastBitcoin.execute(
          'lockup-signed',
          isPsbt: true,
          network: any(named: 'network'),
          walletId: any(named: 'walletId'),
        ),
      ).thenAnswer((_) async => 'lockup-txid');
      when(
        () => recordLockup.execute(
          swapId: 'swap-1',
          txid: 'lockup-txid',
          lockupFeeSat: 1200,
        ),
      ).thenAnswer((_) async => Ok(funded));
      bloc.emit(
        crossChain().copyWith(
          swap: _swap(),
          signedPsbt: 'lockup-signed',
          bitcoinSignature: SpendFixtures.signedBitcoin('lockup-signed'),
          bitcoinAbsoluteFeesSat: 1200,
        ),
      );

      bloc.add(const TransferEvent.confirmed());
      await bloc.stream.firstWhere((state) => state.txId == 'lockup-txid');

      expect(bloc.state.swap?.status, SwapStatus.paid);
      verify(
        () => recordLockup.execute(
          swapId: 'swap-1',
          txid: 'lockup-txid',
          lockupFeeSat: 1200,
        ),
      ).called(1);
    });

    group('with the lockup stored before broadcasting', () {
      TransferState confirming({ChainSwap? swap}) => crossChain().copyWith(
        swap: swap ?? _swap(),
        signedPsbt: 'lockup-signed',
        bitcoinSignature: SpendFixtures.signedBitcoin('lockup-signed'),
        bitcoinAbsoluteFeesSat: 1200,
      );

      void stubBroadcast(Future<String> Function() answer) => when(
        () => broadcastBitcoin.execute(
          'lockup-signed',
          isPsbt: true,
          network: any(named: 'network'),
          walletId: any(named: 'walletId'),
        ),
      ).thenAnswer((_) => answer());

      test('stores the signed lockup, then broadcasts it', () async {
        stubBroadcast(() async => 'lockup-txid');
        when(
          () => recordLockup.execute(
            swapId: any(named: 'swapId'),
            txid: any(named: 'txid'),
            lockupFeeSat: any(named: 'lockupFeeSat'),
          ),
        ).thenAnswer((_) async => Ok(_swap()));
        bloc.emit(confirming());

        bloc.add(const TransferEvent.confirmed());
        await pumpEventQueue();

        verifyInOrder([
          () => recordPendingLockup.execute(
            swapId: 'swap-1',
            signedTx: 'lockup-signed',
          ),
          () => broadcastBitcoin.execute(
            'lockup-signed',
            isPsbt: true,
            network: any(named: 'network'),
            walletId: any(named: 'walletId'),
          ),
        ]);
      });

      test('broadcasts nothing when the lockup cannot be stored', () async {
        when(
          () => recordPendingLockup.execute(
            swapId: any(named: 'swapId'),
            signedTx: any(named: 'signedTx'),
          ),
        ).thenAnswer((_) async => const Err(SwapsUnexpectedFailure('store')));
        bloc.emit(confirming());

        bloc.add(const TransferEvent.confirmed());
        await pumpEventQueue();

        verifyNever(
          () => broadcastBitcoin.execute(
            any(),
            isPsbt: any(named: 'isPsbt'),
            network: any(named: 'network'),
            walletId: any(named: 'walletId'),
          ),
        );
        expect(bloc.state.swapFailure, isA<SwapInvalidStateFailure>());
      });

      test('a broadcast the node rejected forgets the lockup', () async {
        stubBroadcast(
          () async => throw CategorizedBroadcastException(
            BroadcastFailureCategory.rejected,
          ),
        );
        bloc.emit(confirming());

        bloc.add(const TransferEvent.confirmed());
        await pumpEventQueue();

        verify(() => dropPendingLockup.execute('swap-1')).called(1);
      });

      test('an unclear broadcast keeps the lockup', () async {
        stubBroadcast(
          () async => throw CategorizedBroadcastException(
            BroadcastFailureCategory.connection,
          ),
        );
        bloc.emit(confirming());

        bloc.add(const TransferEvent.confirmed());
        await pumpEventQueue();

        verifyNever(() => dropPendingLockup.execute(any()));
      });

      for (final (category, dropsLockup) in [
        (BroadcastFailureCategory.connection, false),
        (BroadcastFailureCategory.authorization, true),
      ]) {
        test('Liquid lockup after ${category.name}', () async {
          final swap = _swap().copyWith(type: SwapType.liquidToBitcoin);
          final pending = swap.copyWith(pendingLockupTx: 'lockup-signed');
          when(
            () => recordPendingLockup.execute(
              swapId: swap.id,
              signedTx: 'lockup-signed',
            ),
          ).thenAnswer((_) async => Ok(pending));
          when(() => broadcastLiquid.execute('lockup-signed'))
              .thenThrow(CategorizedBroadcastException(category));
          bloc.emit(
            confirming(swap: swap).copyWith(
              fromWallet: _liquidWallet(),
              toWallet: _destinationWallet(),
              bitcoinSignature: null,
              liquidSignature: SpendFixtures.signedLiquid('lockup-signed'),
            ),
          );

          final finished = bloc.stream.firstWhere(
            (state) => !state.isConfirming && state.swapFailure != null,
          );
          bloc.add(const TransferEvent.confirmed());
          await finished;

          verify(() => broadcastLiquid.execute('lockup-signed')).called(1);
          if (dropsLockup) {
            verify(() => dropPendingLockup.execute(swap.id)).called(1);
          } else {
            verifyNever(() => dropPendingLockup.execute(swap.id));
            expect(bloc.state.swap?.pendingLockupTx, 'lockup-signed');
            expect(bloc.state.swapFailure, isA<SwapLockupPendingFailure>());
          }
        });
      }

      test('a lockup still being confirmed refuses a rebuild', () async {
        bloc.emit(
          confirming(swap: _swap().copyWith(pendingLockupTx: 'lockup-signed'))
              .copyWith(amount: '1000'),
        );

        bloc.add(const TransferEvent.replaceByFeeChanged(false));
        await pumpEventQueue();

        expect(bloc.state.swapFailure, isA<SwapLockupPendingFailure>());
        verifyNever(
          () => prepareBitcoin.execute(
            walletId: any(named: 'walletId'),
            recipients: any(named: 'recipients'),
            networkFee: any(named: 'networkFee'),
            selectedInputs: any(named: 'selectedInputs'),
            replaceByFee: any(named: 'replaceByFee'),
          ),
        );
      });
    });

    test('watched Boltz updates move the in-progress swap', () async {
      final controller = StreamController<Swap>();
      addTearDown(controller.close);
      when(() => watchSwap.execute('swap-1'))
          .thenAnswer((_) => controller.stream);
      when(() => getSwapRoute.execute())
          .thenAnswer((_) async => SwapRoute.boltz);
      stubCreateChain(Ok(_swap()));
      stubLockupBuild();
      bloc.emit(crossChain());
      bloc.add(const TransferEvent.swapCreated('1000'));
      await bloc.stream.firstWhere((state) => !state.isCreatingSwap);
      bloc.emit(bloc.state.copyWith(txId: 'lockup-txid'));

      controller.add(_swap().copyWith(status: SwapStatus.completed));
      await bloc.stream.firstWhere(
        (state) => state.swap?.status == SwapStatus.completed,
      );

      expect(bloc.state.swap?.status, SwapStatus.completed);
    });
  });
  test(
    'regtest transfer ignores pending Orders from another environment',
    () async {
      final source = _liquidWallet().copyWith(network: LiquidNetwork.regtest);
      final destination = _destinationWallet().copyWith(
        network: BitcoinNetwork.regtest,
      );
      when(() => getSettings.fetch()).thenAnswer(
        (_) async => Ok(
          const SettingsEntity(
            environment: Environment.regtest,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
          ),
        ),
      );
      when(() => orders.getPendingOrders())
          .thenAnswer((_) async => Ok([prepared]));
      when(() => getWallets.execute(any()))
          .thenAnswer((_) async => Ok([source, destination]));
      when(() => getNetworkFees.estimate(any()))
          .thenAnswer((_) async => Ok(_feeOptions()));
      when(() => getExchangeRate.execute(currencyCode: 'USD'))
          .thenAnswer((_) async => const Ok(1.0));
      when(() => getSwapRoute.execute())
          .thenAnswer((_) async => SwapRoute.boltz);
      when(() => getLimitsAndFees.execute(any()))
          .thenAnswer((_) async => const Err(SwapsBoltzUnavailableFailure()));
      bloc.add(const TransferEvent.started());
      await bloc.stream.firstWhere((state) => !state.isStarting);
      expect(bloc.state.startError, isNull);
      expect(bloc.state.fromWallet, source);
      expect(bloc.state.toWallet, destination);
      expect(bloc.state.orderSwap, isNull);
      verify(() => orders.getPendingOrders()).called(1);
      verifyNever(() => orders.watchOrder(any()));
      verifyOrderWasNotCreated();
    },
  );

  test('regtest transfer does not interpret a pending Lightning Order as a binary network', () async {
    final source = _liquidWallet().copyWith(network: LiquidNetwork.regtest);
    final destination = _destinationWallet().copyWith(
      network: BitcoinNetwork.regtest,
    );
    when(() => getSettings.fetch()).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.regtest,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      ),
    );
    when(() => orders.getPendingOrders()).thenAnswer(
      (_) async => Ok([_prepared(purpose: OrderSwapPurpose.receiveLightning)]),
    );
    when(() => getWallets.execute(any()))
        .thenAnswer((_) async => Ok([source, destination]));
    when(() => getNetworkFees.estimate(any()))
        .thenAnswer((_) async => Ok(_feeOptions()));
    when(() => getExchangeRate.execute(currencyCode: 'USD'))
        .thenAnswer((_) async => const Ok(1.0));
    when(() => getSwapRoute.execute()).thenAnswer((_) async => SwapRoute.boltz);
    when(() => getLimitsAndFees.execute(any()))
        .thenAnswer((_) async => const Err(SwapsBoltzUnavailableFailure()));
    bloc.add(const TransferEvent.started());
    await bloc.stream.firstWhere((state) => !state.isStarting);
    expect(bloc.state.startError, isNull);
    expect(bloc.state.fromWallet, source);
    expect(bloc.state.orderSwap, isNull);
    verify(() => orders.getPendingOrders()).called(1);
    verifyNever(() => orders.watchOrder(any()));
    verifyOrderWasNotCreated();
  });

  test(
    'a concrete Bitcoin regtest destination reaches Liquid to Bitcoin Boltz',
    () async {
      when(() => getSwapRoute.execute())
          .thenAnswer((_) async => SwapRoute.boltz);
      when(
        () => detectBitcoin.execute(
          data: 'destination',
          environment: any(named: 'environment'),
        ),
      ).thenAnswer(
        (_) async => const PaymentRequest.bip21(
          network: BitcoinNetwork.regtest,
          uri: 'bitcoin:bcrt1fixture',
          address: 'bcrt1fixture',
        ),
      );
      when(
        () => createLiquidToBitcoin.execute(
          sendWalletId: 'wallet-1:regtest',
          amountSat: any(named: 'amountSat'),
          destination: any(named: 'destination'),
        ),
      ).thenAnswer(
        (_) async => const Err(SwapsBoltzRejectedFailure('fixture')),
      );
      bloc.emit(
        TransferState(
          fromWallet: _liquidWallet().copyWith(
            network: LiquidNetwork.regtest,
            balanceSat: BigInt.from(100000),
          ),
          toWallet: _destinationWallet().copyWith(
            network: BitcoinNetwork.regtest,
          ),
          sendToExternal: true,
          externalAddress: 'destination',
          bitcoinUnit: BitcoinUnit.sats,
          liquidNetworkFees: _feeOptions(),
          bitcoinNetworkFees: _feeOptions(),
          receiveExactAmount: false,
        ),
      );
      bloc.add(const TransferEvent.swapCreated('1000'));
      await bloc.stream.firstWhere((state) => !state.isCreatingSwap);
      verify(
        () => createLiquidToBitcoin.execute(
          sendWalletId: 'wallet-1:regtest',
          amountSat: any(named: 'amountSat'),
          destination: any(named: 'destination'),
        ),
      ).called(1);
    },
  );
  for (final destination in <Network>[
    BitcoinNetwork.testnet,
    LiquidNetwork.regtest,
  ]) {
    test(
      'regtest Transfer refuses a concrete $destination destination before native create',
      () async {
        when(() => getSwapRoute.execute())
            .thenAnswer((_) async => SwapRoute.boltz);
        when(
          () => detectBitcoin.execute(
            data: 'destination',
            environment: NetworkEnv.regtest,
          ),
        ).thenAnswer(
          (_) async => PaymentRequest.bip21(
            network: destination,
            uri: 'public-fixture',
            address: 'public-fixture',
          ),
        );
        bloc.emit(
          TransferState(
            fromWallet: _liquidWallet().copyWith(
              network: LiquidNetwork.regtest,
              balanceSat: BigInt.from(100000),
            ),
            toWallet: _destinationWallet().copyWith(
              network: BitcoinNetwork.regtest,
            ),
            sendToExternal: true,
            externalAddress: 'destination',
            bitcoinUnit: BitcoinUnit.sats,
            liquidNetworkFees: _feeOptions(),
            bitcoinNetworkFees: _feeOptions(),
            receiveExactAmount: false,
          ),
        );
        bloc.add(const TransferEvent.swapCreated('1000'));
        await bloc.stream.firstWhere((state) => !state.isCreatingSwap);
        verify(
          () => detectBitcoin.execute(
            data: 'destination',
            environment: NetworkEnv.regtest,
          ),
        ).called(1);
        verifyZeroInteractions(createLiquidToBitcoin);
        verifyZeroInteractions(createBitcoinToLiquid);
        verifyOrderWasNotCreated();
      },
    );
  }
}

OrderSwapRecord _prepared({
  OrderSwapPurpose purpose = OrderSwapPurpose.transfer,
  OrderSwapLocalStatus status = OrderSwapLocalStatus.readyToBroadcast,
  String? transactionId,
  String payinStatus = 'In progress',
  OrderSwap? order,
}) => OrderSwapRecord(
  localId: 'local-1',
  purpose: purpose,
  environment: OrderSwapEnvironment.testnet,
  inNetwork: OrderSwapNetwork.liquid,
  outNetwork: OrderSwapNetwork.bitcoin,
  isInAmountFixed: false,
  requestedAmountSat: BigInt.from(1000),
  sourceWalletId: 'wallet-1',
  destinationWalletId: 'wallet-2',
  destination: 'destination',
  fallback: 'fallback',
  order: order ?? _order(payinStatus: payinStatus),
  createdAt: DateTime.utc(2026),
  localStatus: status,
  localPayinTransactionId: transactionId,
  signedPayinTransaction: 'signed-psbt',
  payinIsPsbt: true,
);

OrderSwap _order({String payinStatus = 'In progress', DateTime? deadline}) =>
    OrderSwap(
      orderId: 'order-1',
      orderNumber: 1,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.bitcoin,
      payinAmountSat: BigInt.from(1010),
      payoutAmountSat: BigInt.from(1000),
      payinCurrency: 'LBTC',
      payoutCurrency: 'BTC',
      payinMethod: 'Liquid',
      payoutMethod: 'Bitcoin',
      orderType: 'Swap',
      orderStatus: 'Awaiting payment',
      payinStatus: payinStatus,
      payoutStatus: 'Not started',
      messageCode: 'ORDER_CREATED',
      bitcoinAddress: 'destination',
      liquidAddress: 'liquid-address',
      createdAt: DateTime.utc(2026),
      confirmationDeadline:
          deadline ?? DateTime.now().toUtc().add(const Duration(days: 365)),
    );

ChainSwap _swap() => Swap.chain(
  id: 'swap-1',
  keyIndex: 0,
  type: SwapType.bitcoinToLiquid,
  status: SwapStatus.pending,
  environment: swaps.Environment.testnet,
  creationTime: DateTime.utc(2026),
  sendWalletId: 'wallet-1',
  paymentAddress: 'payin-address',
  paymentAmount: 1000,
) as ChainSwap;

SwapWallet _wallet({BigInt? balanceSat}) => SwapWallet(
  walletRegistrationForTesting(
    id: 'wallet-1',
    network: BitcoinNetwork.testnet,
    isDefault: false,
    signer: WalletSigner.local,
  ),
  balanceSat ?? BigInt.zero,
  false,
);

native.Coin _bitcoinUtxo(String txId) => native.BitcoinCoin(
  outpoint: (txId: txId, vout: 0),
  scriptPubkey: Uint8List.fromList([0]),
  amountSat: BigInt.from(2000),
  address: 'tb1qsource',
  keychain: native.Keychain.external,
  confirmations: 0,
);

SwapWallet _liquidWallet({String id = 'wallet-1', bool isDefault = false}) =>
    SwapWallet(
      walletRegistrationForTesting(
        id: id,
        network: LiquidNetwork.testnet,
        isDefault: isDefault,
        signer: WalletSigner.local,
      ),
      BigInt.zero,
      false,
    );

SwapWallet _destinationWallet({
  String id = 'wallet-2',
  bool isDefault = false,
}) => SwapWallet(
  walletRegistrationForTesting(
    id: id,
    network: BitcoinNetwork.testnet,
    isDefault: isDefault,
    signer: WalletSigner.local,
  ),
  BigInt.from(2000),
  false,
);

FeeOptions _feeOptions() => const FeeOptions(
  fastest: RelativeFee(250),
  economic: RelativeFee(250),
  slow: RelativeFee(250),
  minRelay: RelativeFee(25),
);

WalletUtxo _legacyCoin(native.Coin coin, String walletId) => switch (coin) {
  native.BitcoinCoin() => WalletUtxo.bitcoin(
    walletId: walletId,
    txId: coin.outpoint.txId,
    vout: coin.outpoint.vout,
    scriptPubkey: coin.scriptPubkey,
    amountSat: coin.amountSat,
    address: coin.address ?? '',
    addressKeyChain: coin.keychain,
    isFrozen: coin.frozen,
    confirmations: coin.confirmations,
  ),
  native.LiquidCoin() => WalletUtxo.liquid(
    walletId: walletId,
    txId: coin.outpoint.txId,
    vout: coin.outpoint.vout,
    scriptPubkey: coin.scriptPubkey,
    amountSat: coin.amountSat,
    standardAddress: coin.standardAddress,
    confidentialAddress: coin.confidentialAddress,
    isFrozen: coin.frozen,
    blockHeight: coin.blockHeight,
  ),
};

final class _SwapSpend extends FakeSpend {
  final TransferState Function() read;
  final PrepareBitcoinSendUsecase btc;
  final _ValidateBitcoinSelection selection;
  final PrepareLiquidSendUsecase lbtc;
  final CalculateBitcoinAbsoluteFeesUsecase btcFees;
  final CalculateLiquidAbsoluteFeesUsecase liquidFees;
  final SignBitcoinTxUsecase btcSign;
  final SignLiquidTxUsecase liquidSign;
  final BroadcastBitcoinTransactionUsecase btcBroadcast;
  final BroadcastLiquidTransactionUsecase liquidBroadcast;
  final BitcoinSpendPreview? Function() readPreview;

  _SwapSpend({
    required this.read,
    required this.btc,
    required this.selection,
    required this.lbtc,
    required this.btcFees,
    required this.liquidFees,
    required this.btcSign,
    required this.liquidSign,
    required this.btcBroadcast,
    required this.liquidBroadcast,
    required this.readPreview,
  });

  List<WalletUtxo>? coins(
    Set<primitives.Outpoint>? requested,
    String walletId,
  ) => requested == null || requested.isEmpty
      ? null
      : [
          for (final coin in read().selectedUtxos)
            if (requested.contains(coin.outpoint)) _legacyCoin(coin, walletId),
        ];

  @override
  Future<Result<bool, SpendFailure>> needsLiquidConsolidation(
    String walletId, {
    required int highUtxoThreshold,
  }) async => const Ok(false);

  @override
  Future<Result<void, SpendFailure>> validateBitcoinSelection({
    required String walletId,
    Set<primitives.Outpoint>? selectedInputs,
  }) async {
    return selection.execute(
      walletId: walletId,
      selectedInputs: selectedInputs,
    );
  }

  @override
  Future<Result<PreparedBitcoinSpend, SpendFailure>> prepareBitcoin({
    required String walletId,
    required List<primitives.BitcoinTransactionRecipient> recipients,
    required NetworkFee networkFee,
    Set<primitives.Outpoint>? selectedInputs,
    bool selectedOnly = false,
    bool replaceByFee = true,
  }) async {
    try {
      final result = await btc.execute(
        walletId: walletId,
        recipients: recipients,
        networkFee: networkFee,
        selectedInputs:
            networkFee == read().selectedFee || selectedInputs == null
            ? coins(selectedInputs, walletId)
            : coins(selectedInputs, walletId) ?? const [],
        replaceByFee: replaceByFee,
        selectedOnly: selectedOnly,
      );
      if (result case Ok(:final value)) {
        return Ok(
          SpendFixtures.preparedBitcoin(
            unsignedPsbt: value.unsignedPsbt,
            fee: Sats.fromInt(await btcFees.execute(psbt: value.unsignedPsbt)),
            txSize: value.txSize,
            isToSelf: value.isToSelf,
            recipientAmountsSat: value.recipientAmountsSat,
          ),
        );
      }
      return Err(
        switch ((result as Err<PreparedBitcoinSend, SendFailure>).failure) {
          SendInsufficientBalanceFailure() =>
            const SpendInsufficientFundsFailure(),
          SendSelectedCoinsInsufficientFailure() =>
            const SpendNoSpendableInputsFailure(),
          SendSelectedCoinsUnavailableFailure() =>
            const SpendSelectedInputsUnavailableFailure(),
          _ => const SpendBuildRefusedFailure(),
        },
      );
    } on WalletSpendBlockedException catch (blocked) {
      return Err(
        SpendUnavailableFailure(
          busy: blocked.status == BitcoinSpendStatus.busy,
        ),
      );
    } on InsufficientFundsException {
      return const Err(SpendInsufficientFundsFailure());
    } on NoSpendableUtxoException {
      return const Err(SpendNoSpendableInputsFailure());
    }
  }

  @override
  Future<Result<Map<FeeSelection, BitcoinSpendPreview?>, SpendFailure>>
  previewBitcoinFeePresets({
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required FeeOptions presets,
    required bool replaceByFee,
    required Set<primitives.Outpoint> selectedInputs,
    bool selectedOnly = false,
  }) async => Ok({FeeSelection.fastest: readPreview()});

  @override
  Future<Result<PreparedLiquidSpend, SpendFailure>> prepareLiquid({
    required String walletId,
    required String address,
    required RelativeFee feeRate,
    int? amountSat,
    bool drain = false,
    Set<primitives.Outpoint>? selectedInputs,
  }) async {
    final result = await lbtc.execute(
      walletId: walletId,
      address: address,
      feeRate: feeRate,
      amountSat: amountSat,
      drain: drain,
      selectedInputs: selectedInputs,
    );
    return switch (result) {
      Ok(value: final pset) => Ok(
        SpendFixtures.preparedLiquid(
          unsignedPset: pset,
          fee: Sats.fromInt(await liquidFees.execute(pset: pset)),
          amountSent: Sats.fromInt(amountSat ?? 0),
        ),
      ),
      Err(failure: SpendConsolidationRequiredFailure()) => const Err(
        SpendConsolidationRequiredFailure(),
      ),
      Err(failure: SpendInsufficientFundsFailure()) => const Err(
        SpendInsufficientFundsFailure(),
      ),
      Err() => const Err(SpendBuildRefusedFailure()),
    };
  }

  @override
  Future<Result<SignedBitcoinSpend, SpendFailure>> signBitcoin({
    required PreparedBitcoinSpend prepared,
  }) async {
    final source = read().fromWallet;
    if (source == null) return const Err(SpendInvalidRequestFailure());
    final signed = await btcSign.execute(
      walletId: source.id,
      psbt: prepared.unsignedPsbt,
    );
    return Ok(
      SpendFixtures.signedBitcoin(signed.signedPsbt, txSize: signed.txSize),
    );
  }

  @override
  Future<Result<SignedLiquidSpend, SpendFailure>> signLiquid({
    required PreparedLiquidSpend prepared,
  }) async {
    final source = read().fromWallet;
    if (source == null) return const Err(SpendInvalidRequestFailure());
    return Ok(
      SpendFixtures.signedLiquid(
        await liquidSign.execute(
          walletId: source.id,
          pset: prepared.unsignedPset,
        ),
      ),
    );
  }

  Future<Result<SpendBroadcastReceipt, SpendFailure>> _send(
    Future<String> Function() action, {
    required bool guarded,
  }) async {
    try {
      return Ok((txid: await action(), guarded: guarded, durable: guarded));
    } on WalletSpendBlockedException catch (blocked) {
      return Err(
        SpendUnavailableFailure(
          busy: blocked.status == BitcoinSpendStatus.busy,
        ),
      );
    } on BroadcastTransactionException catch (error) {
      return Err(switch (BroadcastFailureCategory.of(error)) {
        BroadcastFailureCategory.rejected =>
          const SpendBroadcastRejectedFailure(
            SpendBroadcastRejection.nodeRejected,
          ),
        BroadcastFailureCategory.authorization =>
          const SpendDeveloperAuthorizationFailure(),
        BroadcastFailureCategory.connection when !guarded =>
          const SpendBroadcastConnectionFailure(),
        _ => const SpendBroadcastOutcomeUnknownFailure(),
      });
    }
  }

  @override
  Future<Result<SpendBroadcastReceipt, SpendFailure>> broadcastBitcoin(
    SignedBitcoinSpend signed,
  ) async {
    final source = read().fromWallet;
    if (source == null) return const Err(SpendInvalidRequestFailure());
    return _send(
      () => btcBroadcast.execute(
        signed.signedTransaction,
        network: source.network,
        isPsbt: true,
        walletId: source.id,
      ),
      guarded: true,
    );
  }

  @override
  Future<Result<SpendBroadcastReceipt, SpendFailure>> broadcastLiquid(
    SignedLiquidSpend signed,
  ) => _send(() => liquidBroadcast.execute(signed.signedPset), guarded: false);

  @override
  Future<Result<SpendBroadcastReceipt, SpendFailure>> resumeBitcoinPayin({
    required String signedPsbt,
    required String walletId,
    required primitives.BitcoinNetwork network,
    required String address,
    required primitives.Sats amount,
    bool isPsbt = true,
  }) => broadcastBitcoin(SpendFixtures.signedBitcoin(signedPsbt));

  @override
  Future<Result<SpendBroadcastReceipt, SpendFailure>> resumeLiquidPayin({
    required String signedPset,
    required String walletId,
    required primitives.LiquidNetwork network,
    required String address,
    required primitives.Sats amount,
  }) => broadcastLiquid(SpendFixtures.signedLiquid(signedPset));
}

extension on SwapWallet {
  SwapWallet copyWith({Network? network, BigInt? balanceSat, String? origin}) {
    final target = network ?? this.network;
    final baseId = origin ?? id.replaceFirst(RegExp(r':regtest$'), '');
    return SwapWallet(
      walletRegistrationForTesting(
        id: target.env == NetworkEnv.regtest ? '$baseId:regtest' : baseId,
        network: target,
        isDefault: isDefault,
        signer: registration.signer,
      ),
      balanceSat ?? this.balanceSat,
      isHardwareWallet,
    );
  }
}
