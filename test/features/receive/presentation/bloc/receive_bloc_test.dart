import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/entities/signer_entity.dart' show SignerEntity;
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_address_usecase.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:bb_mobile/features/receive/domain/usecases/convert_receive_amount_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/fetch_receive_note_suggestions_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_address_at_index_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_currencies_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_settings_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_wallets_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/load_receive_address_label_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/prepare_receive_address_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/save_receive_address_label_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_payjoin_policy_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/create_receive_order_swap_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/set_receive_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/watch_receive_order_swap_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/watch_receive_payjoin_min_amount_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/watch_receive_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;

class _MockGetReceiveWalletsUsecase extends Mock
    implements GetReceiveWalletsUsecase {}

class _MockGetReceiveCurrenciesUsecase extends Mock
    implements GetReceiveCurrenciesUsecase {}

class _MockGetReceiveSettingsUsecase extends Mock
    implements GetReceiveSettingsUsecase {}

class _MockConvertReceiveAmountUsecase extends Mock
    implements ConvertReceiveAmountUsecase {}

class _MockPrepareReceiveAddressUsecase extends Mock
    implements PrepareReceiveAddressUsecase {}

class _MockGetReceiveAddressAtIndexUsecase extends Mock
    implements GetReceiveAddressAtIndexUsecase {}

class _MockCreateReceiveOrderSwapUsecase extends Mock
    implements CreateReceiveOrderSwapUsecase {}

class _MockReceiveWithPayjoinUsecase extends Mock
    implements ReceiveWithPayjoinUsecase {}

class _MockBroadcastOriginalTransactionUsecase extends Mock
    implements BroadcastOriginalTransactionUsecase {}

class _MockWatchPayjoinUsecase extends Mock implements WatchPayjoinUsecase {}

class _MockWatchWalletTransactionByAddressUsecase extends Mock
    implements WatchWalletTransactionByAddressUsecase {}

class _MockWatchReceiveOrderSwapUsecase extends Mock
    implements WatchReceiveOrderSwapUsecase {}

class _MockLoadReceiveAddressLabelUsecase extends Mock
    implements LoadReceiveAddressLabelUsecase {}

class _MockSaveReceiveAddressLabelUsecase extends Mock
    implements SaveReceiveAddressLabelUsecase {}

class _MockFetchReceiveNoteSuggestionsUsecase extends Mock
    implements FetchReceiveNoteSuggestionsUsecase {}

class _MockWatchReceivePayjoinEnabledUsecase extends Mock
    implements WatchReceivePayjoinEnabledUsecase {}

class _MockGetReceivePayjoinPolicyUsecase extends Mock
    implements GetReceivePayjoinPolicyUsecase {}

class _MockSetReceivePayjoinEnabledUsecase extends Mock
    implements SetReceivePayjoinEnabledUsecase {}

class _MockWatchReceivePayjoinMinAmountUsecase extends Mock
    implements WatchReceivePayjoinMinAmountUsecase {}

class _LateOrderSwapStream
    extends Stream<Result<OrderSwapRecord, ReceiveFailure>> {
  void Function(Result<OrderSwapRecord, ReceiveFailure>)? _onData;

  void emit(OrderSwapRecord record) => _onData?.call(Ok(record));

  @override
  StreamSubscription<Result<OrderSwapRecord, ReceiveFailure>> listen(
    void Function(Result<OrderSwapRecord, ReceiveFailure> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    _onData = onData;
    return _NoopSubscription<Result<OrderSwapRecord, ReceiveFailure>>();
  }
}

class _NoopSubscription<T> implements StreamSubscription<T> {
  _NoopSubscription({Future<void>? cancelFuture})
    : _cancelFuture = cancelFuture ?? Future<void>.value();

  final Future<void> _cancelFuture;

  @override
  Future<void> cancel() => _cancelFuture;

  @override
  void onData(void Function(T data)? handleData) {}

  @override
  void onError(Function? handleError) {}

  @override
  void onDone(void Function()? handleDone) {}

  @override
  void pause([Future<void>? resumeSignal]) {}

  @override
  void resume() {}

  @override
  bool get isPaused => false;

  @override
  Future<E> asFuture<E>([E? futureValue]) async => futureValue as E;
}

class _ControlledCancelPayjoinStream
    extends Stream<Result<PayjoinSession, ReceiveFailure>> {
  _ControlledCancelPayjoinStream(this.cancelFuture);

  final Future<void> cancelFuture;

  @override
  StreamSubscription<Result<PayjoinSession, ReceiveFailure>> listen(
    void Function(Result<PayjoinSession, ReceiveFailure> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _NoopSubscription(cancelFuture: cancelFuture);
}

// Defaults to a confirmed balance: most tests in this file are about the
// isPayjoinEnabled/proposal-state gating, not the balance one. The
// balance-eligibility tests override it explicitly.
// confirmedBalanceSat mirrors balanceSat by default: these tests are about
// the isPayjoinEnabled/eligibility gating, not the confirmed-vs-unconfirmed
// distinction, so keeping the two in lockstep here avoids every
// payjoin-creating test failing for a reason unrelated to what it names.
// confirmedBalanceSat is a separate optional override so a test can build a
// wallet with unconfirmed-only funds (balanceSat > 0, confirmedBalanceSat ==
// 0) to cover the accepted unconfirmed-only case.
Wallet _testWallet({
  String origin = 'w1',
  BigInt? balanceSat,
  BigInt? confirmedBalanceSat,
  Network network = Network.bitcoinMainnet,
  SignerEntity signer = SignerEntity.local,
}) => Wallet(
  origin: origin,
  network: network,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: signer,
  signerDevice: null,
  balanceSat: balanceSat ?? BigInt.from(50000),
  confirmedBalanceSat: confirmedBalanceSat ?? balanceSat ?? BigInt.from(50000),
);

WalletAddress _testAddress({String walletId = 'w1'}) => WalletAddress(
  walletId: walletId,
  index: 0,
  address: 'bc1qtest',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

PayjoinReceiverSession _receiver({
  String id = 'pj1',
  String walletId = 'w1',
  Uint8List? originalTxBytes,
  String? proposalPsbt,
  PayjoinStatus status = PayjoinStatus.started,
}) => PayjoinReceiverSession(
  status: status,
  id: id,
  network: BitcoinNetwork.mainnet,
  walletId: walletId,
  payjoinUri: 'bitcoin:bc1qtest?pj=https://payjo.in',
  createdAt: DateTime(2026),
  expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
  hasOriginalTransaction: originalTxBytes != null,
  hasProposal: proposalPsbt != null,
);

void main() {
  late _MockGetReceiveWalletsUsecase getWallets;
  late _MockGetReceiveSettingsUsecase getSettings;
  late _MockGetReceiveCurrenciesUsecase getAvailableCurrencies;
  late _MockConvertReceiveAmountUsecase convertSatsToCurrency;
  late _MockPrepareReceiveAddressUsecase getReceiveAddress;
  late _MockReceiveWithPayjoinUsecase receiveWithPayjoin;
  late _MockBroadcastOriginalTransactionUsecase broadcastOriginalTransaction;
  late _MockWatchPayjoinUsecase watchPayjoin;
  late _MockWatchWalletTransactionByAddressUsecase watchWalletTransaction;
  late _MockLoadReceiveAddressLabelUsecase loadAddressLabel;
  late _MockSaveReceiveAddressLabelUsecase saveAddressLabel;
  late _MockWatchReceivePayjoinEnabledUsecase watchPayjoinEnabledChanges;
  late _MockGetReceivePayjoinPolicyUsecase getPayjoinPolicy;
  late _MockSetReceivePayjoinEnabledUsecase setPayjoinEnabled;
  late _MockWatchReceivePayjoinMinAmountUsecase watchPayjoinMinAmount;
  late _MockCreateReceiveOrderSwapUsecase createOrderSwap;
  late _MockWatchReceiveOrderSwapUsecase watchOrderSwap;
  late StreamController<bool> payjoinEnabledChangeController;
  late StreamController<int> payjoinMinAmountChangeController;

  setUpAll(() {
    registerFallbackValue(_receiver());
    registerFallbackValue(_testWallet());
  });

  ReceiveBloc buildBloc({Wallet? wallet, bool withPresetWallet = true}) =>
      ReceiveBloc(
        getReceiveWalletsUsecase: getWallets,
        getReceiveCurrenciesUsecase: getAvailableCurrencies,
        getReceiveSettingsUsecase: getSettings,
        convertReceiveAmountUsecase: convertSatsToCurrency,
        prepareReceiveAddressUsecase: getReceiveAddress,
        getReceiveAddressAtIndexUsecase: _MockGetReceiveAddressAtIndexUsecase(),
        createReceiveOrderSwapUsecase: createOrderSwap,
        receiveWithPayjoinUsecase: receiveWithPayjoin,
        broadcastOriginalTransactionUsecase: broadcastOriginalTransaction,
        watchPayjoinUsecase: watchPayjoin,
        watchWalletTransactionByAddressUsecase: watchWalletTransaction,
        watchReceiveOrderSwapUsecase: watchOrderSwap,
        loadReceiveAddressLabelUsecase: loadAddressLabel,
        saveReceiveAddressLabelUsecase: saveAddressLabel,
        fetchReceiveNoteSuggestionsUsecase:
            _MockFetchReceiveNoteSuggestionsUsecase(),
        watchReceivePayjoinEnabledUsecase: watchPayjoinEnabledChanges,
        watchReceivePayjoinMinAmountUsecase: watchPayjoinMinAmount,
        getReceivePayjoinPolicyUsecase: getPayjoinPolicy,
        setReceivePayjoinEnabledUsecase: setPayjoinEnabled,
        // A preset bitcoin wallet makes _onBitcoinStarted skip the wallet
        // fetch entirely, so any getWallets stub is dead. Tests that need that
        // path pass withPresetWallet: false.
        wallet: withPresetWallet ? (wallet ?? _testWallet()) : null,
      );

  setUp(() {
    getWallets = _MockGetReceiveWalletsUsecase();
    when(
      () => getWallets.execute(onlyBitcoin: true),
    ).thenAnswer((_) async => Ok([_testWallet(origin: 'default-btc')]));
    getSettings = _MockGetReceiveSettingsUsecase();
    getAvailableCurrencies = _MockGetReceiveCurrenciesUsecase();
    convertSatsToCurrency = _MockConvertReceiveAmountUsecase();
    getReceiveAddress = _MockPrepareReceiveAddressUsecase();
    receiveWithPayjoin = _MockReceiveWithPayjoinUsecase();
    broadcastOriginalTransaction = _MockBroadcastOriginalTransactionUsecase();
    watchPayjoin = _MockWatchPayjoinUsecase();
    watchWalletTransaction = _MockWatchWalletTransactionByAddressUsecase();
    createOrderSwap = _MockCreateReceiveOrderSwapUsecase();
    watchOrderSwap = _MockWatchReceiveOrderSwapUsecase();
    loadAddressLabel = _MockLoadReceiveAddressLabelUsecase();
    saveAddressLabel = _MockSaveReceiveAddressLabelUsecase();
    watchPayjoinEnabledChanges = _MockWatchReceivePayjoinEnabledUsecase();
    getPayjoinPolicy = _MockGetReceivePayjoinPolicyUsecase();
    payjoinEnabledChangeController = StreamController<bool>.broadcast();
    payjoinMinAmountChangeController = StreamController<int>.broadcast();
    when(
      () => watchPayjoinEnabledChanges.execute(),
    ).thenAnswer((_) => payjoinEnabledChangeController.stream);
    when(() => getPayjoinPolicy.execute()).thenAnswer(
      (_) async => const Ok((enabled: true, minimumAmountSat: 10000)),
    );
    watchPayjoinMinAmount = _MockWatchReceivePayjoinMinAmountUsecase();
    when(
      () => watchPayjoinMinAmount.execute(),
    ).thenAnswer((_) => payjoinMinAmountChangeController.stream);
    setPayjoinEnabled = _MockSetReceivePayjoinEnabledUsecase();
    // Toggling persists to settings, which in the real app feeds back via the
    //  change stream; the tests emit on payjoinEnabledChangeController to
    //  simulate that round-trip explicitly.
    when(
      () => setPayjoinEnabled.execute(
        any(),
        requestConsent: any(named: 'requestConsent'),
      ),
    ).thenAnswer((_) async => const Ok<bool, ReceiveFailure>(true));

    // Payjoin is enabled by default here so the guard group can create a
    // session; the gated group overrides this stub to disable it.
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const Ok(
        SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      ),
    );
    when(
      () => getAvailableCurrencies.execute(),
    ).thenAnswer((_) async => const Ok(<String>[]));
    when(
      () => convertSatsToCurrency.execute(
        amountSat: any(named: 'amountSat'),
        currencyCode: any(named: 'currencyCode'),
      ),
    ).thenAnswer((_) async => const Ok(1.0));
    when(
      () => getReceiveAddress.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => Ok(_testAddress()));
    when(
      () => receiveWithPayjoin.execute(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
      ),
    ).thenAnswer((_) async => Ok(_receiver()));
    when(
      () => loadAddressLabel.execute(any()),
    ).thenAnswer((_) async => const Ok(''));
    when(
      () => saveAddressLabel.execute(
        address: any(named: 'address'),
        walletId: any(named: 'walletId'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    // WatchPayjoinUsecase.execute returns package session updates.
    when(() => watchPayjoin.execute(ids: any(named: 'ids'))).thenAnswer(
      (_) => const Stream<Result<PayjoinSession, ReceiveFailure>>.empty(),
    );
    when(
      () => watchWalletTransaction.execute(
        walletId: any(named: 'walletId'),
        toAddress: any(named: 'toAddress'),
      ),
    ).thenAnswer((_) => const Stream.empty());
  });

  tearDown(() async {
    await payjoinEnabledChangeController.close();
    await payjoinMinAmountChangeController.close();
  });

  group('ReceivePayjoinOriginalTxBroadcasted guard', () {
    test(
      'allows the guarded fallback after a proposal has been sent',
      () async {
        // The session already sent a proposal (proposalPsbt != null).
        final proposedPayjoin = _receiver(
          status: PayjoinStatus.proposed,
          originalTxBytes: Uint8List.fromList([1, 2, 3]),
          proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
        );
        when(
          () => receiveWithPayjoin.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
          ),
        ).thenAnswer((_) async => Ok(proposedPayjoin));
        final completedPayjoin = _receiver(
          status: PayjoinStatus.aborted,
          originalTxBytes: Uint8List.fromList([1, 2, 3]),
          proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
        );
        when(
          () => broadcastOriginalTransaction.execute(any()),
        ).thenAnswer((_) async => Ok(completedPayjoin));

        final bloc = buildBloc();
        addTearDown(bloc.close);

        bloc.add(const ReceiveBitcoinStarted(null));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.payjoin, proposedPayjoin);

        bloc.add(const ReceivePayjoinOriginalTxBroadcasted());
        await Future<void>.delayed(Duration.zero);

        verify(
          () => broadcastOriginalTransaction.execute(proposedPayjoin.id),
        ).called(1);
        expect(bloc.state.payjoin, completedPayjoin);
        expect(bloc.state.isBroadcastingOriginalTransaction, isFalse);
      },
    );

    test('broadcasts the original when a request was received but no '
        'proposal went out yet (the legitimate manual fallback)', () async {
      final requestedPayjoin = _receiver(
        status: PayjoinStatus.requested,
        originalTxBytes: Uint8List.fromList([1, 2, 3]),
      );
      when(
        () => receiveWithPayjoin.execute(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
        ),
      ).thenAnswer((_) async => Ok(requestedPayjoin));
      final completedPayjoin = _receiver(
        status: PayjoinStatus.aborted,
        originalTxBytes: Uint8List.fromList([1, 2, 3]),
      );
      when(
        () => broadcastOriginalTransaction.execute(any()),
      ).thenAnswer((_) async => Ok(completedPayjoin));

      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const ReceiveBitcoinStarted(null));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.payjoin, requestedPayjoin);

      bloc.add(const ReceivePayjoinOriginalTxBroadcasted());
      await Future<void>.delayed(Duration.zero);

      verify(
        () => broadcastOriginalTransaction.execute(requestedPayjoin.id),
      ).called(1);
      expect(bloc.state.payjoin, completedPayjoin);
      expect(bloc.state.isBroadcastingOriginalTransaction, isFalse);
    });

    test(
      'does not surface an error when fallback becomes unavailable',
      () async {
        final proposedPayjoin = _receiver(
          status: PayjoinStatus.proposed,
          originalTxBytes: Uint8List.fromList([1, 2, 3]),
          proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
        );
        when(
          () => receiveWithPayjoin.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
          ),
        ).thenAnswer((_) async => Ok(proposedPayjoin));
        when(
          () => broadcastOriginalTransaction.execute(proposedPayjoin.id),
        ).thenAnswer(
          (_) async =>
              const Err(ReceiveBroadcastOriginalTxUnavailableFailure()),
        );

        final bloc = buildBloc();
        addTearDown(bloc.close);
        bloc.add(const ReceiveBitcoinStarted(null));
        await Future<void>.delayed(Duration.zero);

        bloc.add(const ReceivePayjoinOriginalTxBroadcasted());
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.failure, isNull);
        expect(bloc.state.isBroadcastingOriginalTransaction, isFalse);
      },
    );
  });

  // ReceiveState.isPayjoinLoading reads a single flag the bloc sets, rather
  // than re-deriving "will a session ever arrive?" from payjoinGloballyEnabled
  // / signsLocally / hasUtxos / the failure slot. That derivation was the
  // source of three separate "QR stuck loading forever" bugs, each a case it
  // did not enumerate. The invariant now lives here: whatever happens, the
  // bloc must settle the question, so paymentRequest always resolves.
  group('payjoin loading gate always settles', () {
    test('when the user toggles payjoin on and straight back off before the '
        'session is created', () async {
      // restartable() cancels the enable handler mid-flight, dropping the
      // emits that would have settled the flag it had just cleared. The
      // disable handler that replaces it creates no session, so if it only
      // settled alongside tearing one down the QR would never come back.
      final creation =
          Completer<Result<PayjoinReceiverSession, ReceiveFailure>>();
      when(
        () => receiveWithPayjoin.execute(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
        ),
      ).thenAnswer((_) => creation.future);
      when(() => getPayjoinPolicy.execute()).thenAnswer(
        (_) async => const Ok((enabled: false, minimumAmountSat: 10000)),
      );

      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const ReceiveBitcoinStarted(null));
      await pumpEventQueue();
      expect(bloc.state.qrData, isNotEmpty);

      bloc.add(const ReceivePayjoinSettingChanged(true));
      await pumpEventQueue();
      expect(bloc.state.payjoinAttemptSettled, isFalse);

      bloc.add(const ReceivePayjoinSettingChanged(false));
      await pumpEventQueue();

      expect(bloc.state.payjoinAttemptSettled, isTrue);
      expect(bloc.state.isPayjoinLoading, isFalse);
      expect(bloc.state.qrData, isNotEmpty);
    });

    test('when the wallet cannot sign locally', () async {
      when(() => getWallets.execute(onlyBitcoin: true)).thenAnswer(
        (_) async =>
            Ok([_testWallet(origin: 'default-btc', signer: SignerEntity.none)]),
      );

      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const ReceiveBitcoinStarted(null));
      await pumpEventQueue();

      expect(bloc.state.payjoinAttemptSettled, isTrue);
      expect(bloc.state.qrData, isNotEmpty);
    });

    test('when there is no bitcoin wallet at all', () async {
      // GetReceiveWalletsUsecase returns Ok([]) for an empty list; .first
      // would throw a StateError with no try/catch left to convert it.
      when(
        () => getWallets.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => const Ok(<Wallet>[]));

      final bloc = buildBloc(withPresetWallet: false);
      addTearDown(bloc.close);
      bloc.add(const ReceiveBitcoinStarted(null));
      await pumpEventQueue();

      expect(bloc.state.failure, isA<ReceiveAddressUnavailableFailure>());
      expect(bloc.state.payjoinAttemptSettled, isTrue);
    });

    test('when a startup read fails', () async {
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const Err(ReceiveUnexpectedFailure('prefs unreadable')),
      );

      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const ReceiveBitcoinStarted(null));
      await pumpEventQueue();

      expect(bloc.state.failure, isA<ReceiveUnexpectedFailure>());
      expect(bloc.state.payjoinAttemptSettled, isTrue);
    });

    test('when the address cannot be prepared', () async {
      when(
        () => getReceiveAddress.execute(walletId: any(named: 'walletId')),
      ).thenAnswer(
        (_) async => const Err(
          ReceiveAddressUnavailableFailure('bdk: descriptor error'),
        ),
      );

      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const ReceiveBitcoinStarted(null));
      await pumpEventQueue();

      expect(bloc.state.failure, isA<ReceiveAddressUnavailableFailure>());
      expect(bloc.state.payjoinAttemptSettled, isTrue);
    });

    test('when the currency list cannot be read', () async {
      when(() => getAvailableCurrencies.execute()).thenAnswer(
        (_) async => const Err(ReceiveUnexpectedFailure('exchange 503')),
      );

      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const ReceiveBitcoinStarted(null));
      await pumpEventQueue();

      expect(bloc.state.failure, isA<ReceiveUnexpectedFailure>());
      expect(bloc.state.payjoinAttemptSettled, isTrue);
    });

    test('when payjoin is disabled globally', () async {
      when(() => getPayjoinPolicy.execute()).thenAnswer(
        (_) async => const Ok((enabled: false, minimumAmountSat: 10000)),
      );

      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const ReceiveBitcoinStarted(null));
      await pumpEventQueue();

      expect(bloc.state.payjoinAttemptSettled, isTrue);
      expect(bloc.state.isPayjoinLoading, isFalse);
      expect(bloc.state.qrData, isNotEmpty);
    });

    test('when the wallet has no balance to contribute', () async {
      final bloc = buildBloc(wallet: _testWallet(balanceSat: BigInt.zero));
      addTearDown(bloc.close);

      bloc.add(const ReceiveBitcoinStarted(null));
      await pumpEventQueue();

      expect(bloc.state.payjoinAttemptSettled, isTrue);
      expect(bloc.state.qrData, isNotEmpty);
    });

    test('when the session creation fails', () async {
      when(
        () => receiveWithPayjoin.execute(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
        ),
      ).thenAnswer(
        (_) async => const Err(ReceivePayjoinUnavailableFailure('relay down')),
      );

      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const ReceiveBitcoinStarted(null));
      await pumpEventQueue();

      // The failure is logged, not stored: the receive still works, the
      // address just cannot advertise a pj= endpoint.
      expect(bloc.state.payjoin, isNull);
      expect(bloc.state.failure, isNull);
      expect(bloc.state.payjoinAttemptSettled, isTrue);
      expect(bloc.state.qrData, isNotEmpty);
      expect(
        Uri.parse(bloc.state.qrData).queryParameters,
        isNot(contains('pj')),
      );
    });

    test('and stays open until the decision is actually made', () async {
      // Session creation blocks, so the question is still open — the QR must
      // hold rather than render an address-only URI it would then replace.
      final creation =
          Completer<Result<PayjoinReceiverSession, ReceiveFailure>>();
      when(
        () => receiveWithPayjoin.execute(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
        ),
      ).thenAnswer((_) => creation.future);

      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const ReceiveBitcoinStarted(null));
      await pumpEventQueue();

      expect(bloc.state.payjoinAttemptSettled, isFalse);
      expect(bloc.state.isPayjoinLoading, isTrue);
      expect(bloc.state.qrData, isEmpty);
      // The address itself is available for copying while the QR waits.
      expect(bloc.state.clipboardData, isNotEmpty);

      creation.complete(Ok(_receiver()));
      await pumpEventQueue();

      expect(bloc.state.payjoinAttemptSettled, isTrue);
      expect(bloc.state.qrData, contains('pj='));
    });
  });

  group('failures that must NOT surface, and one that must', () {
    test('an unreadable payjoin policy fails closed and stays silent: the '
        'address still works, so there is nothing to tell the user', () async {
      when(() => getPayjoinPolicy.execute()).thenAnswer(
        (_) async => const Err(
          ReceivePayjoinPolicyUnavailableFailure('settings stream closed'),
        ),
      );

      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const ReceiveBitcoinStarted(null));
      await pumpEventQueue();

      expect(bloc.state.failure, isNull);
      expect(bloc.state.payjoinGloballyEnabled, isFalse);
      expect(bloc.state.payjoin, isNull);
      expect(bloc.state.qrData, isNotEmpty);
      expect(bloc.state.qrData, isNot(contains('pj=')));
    });

    test('a failed payjoin session creation stays silent too', () async {
      when(
        () => receiveWithPayjoin.execute(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
        ),
      ).thenAnswer(
        (_) async => const Err(ReceivePayjoinUnavailableFailure('relay down')),
      );

      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const ReceiveBitcoinStarted(null));
      await pumpEventQueue();

      expect(bloc.state.failure, isNull);
      expect(bloc.state.qrData, isNotEmpty);
    });

    test(
      'a failed payjoin session update is dropped, not surfaced: the '
      'session on screen is still valid and the next poll may succeed',
      () async {
        final updates =
            StreamController<Result<PayjoinSession, ReceiveFailure>>();
        addTearDown(updates.close);
        when(
          () => watchPayjoin.execute(ids: any(named: 'ids')),
        ).thenAnswer((_) => updates.stream);

        final bloc = buildBloc();
        addTearDown(bloc.close);
        bloc.add(const ReceiveBitcoinStarted(null));
        await pumpEventQueue();

        updates.add(const Err(ReceivePayjoinUnavailableFailure('poll failed')));
        await pumpEventQueue();

        expect(bloc.state.failure, isNull);
        expect(bloc.state.payjoin, isNotNull);
      },
    );

    test('a failed order-swap update IS surfaced: it is the swap the user is '
        'waiting on', () async {
      final record = _receiveOrderSwapRecord();
      final updates =
          StreamController<Result<OrderSwapRecord, ReceiveFailure>>();
      addTearDown(updates.close);
      when(
        () => createOrderSwap.execute(
          wallet: any(named: 'wallet'),
          amountSat: 1000,
          note: any(named: 'note'),
        ),
      ).thenAnswer((_) async => Ok(record));
      when(
        () => watchOrderSwap.execute(record.localId),
      ).thenAnswer((_) => updates.stream);

      final bloc = buildBloc(
        wallet: _testWallet(network: Network.liquidTestnet),
      );
      addTearDown(bloc.close);
      bloc.add(const ReceiveLightningStarted());
      await pumpEventQueue();
      bloc.add(const ReceiveAmountInputChanged('1000'));
      bloc.add(const ReceiveAmountConfirmed());
      await pumpEventQueue();

      updates.add(const Err(ReceiveNetworkFailure('boltz unreachable')));
      await pumpEventQueue();

      expect(bloc.state.failure, isA<ReceiveNetworkFailure>());
    });

    test(
      'a failed toggle surfaces, because the user just asked for it',
      () async {
        when(
          () => setPayjoinEnabled.execute(
            any(),
            requestConsent: any(named: 'requestConsent'),
          ),
        ).thenAnswer(
          (_) async =>
              const Err(ReceivePayjoinSettingFailure('shared_prefs EACCES')),
        );

        final bloc = buildBloc();
        addTearDown(bloc.close);
        bloc.add(const ReceiveBitcoinStarted(null));
        await pumpEventQueue();

        bloc.add(ReceivePayjoinToggled(true, () async => true));
        await pumpEventQueue();

        expect(bloc.state.failure, isA<ReceivePayjoinSettingFailure>());
      },
    );
  });

  group('payjoin gated on the global setting', () {
    test('does NOT create a payjoin receiver session when payjoin is '
        'disabled globally', () async {
      when(() => getPayjoinPolicy.execute()).thenAnswer(
        (_) async => const Ok((enabled: false, minimumAmountSat: 10000)),
      );

      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const ReceiveBitcoinStarted(null));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.payjoin, isNull);
      expect(bloc.state.payjoinGloballyEnabled, isFalse);
      verifyNever(
        () => receiveWithPayjoin.execute(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
        ),
      );
    });

    test('creates a payjoin receiver session when payjoin is enabled '
        'globally', () async {
      final createdPayjoin = _receiver();
      when(
        () => receiveWithPayjoin.execute(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
        ),
      ).thenAnswer((_) async => Ok(createdPayjoin));

      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const ReceiveBitcoinStarted(null));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.payjoin, createdPayjoin);
      expect(bloc.state.payjoinGloballyEnabled, isTrue);
    });

    test(
      'a toggle-off arriving while _onBitcoinStarted\'s session creation '
      'is in flight wins: no payjoin surfaces and no watcher is armed',
      () async {
        // Session creation blocks until we complete it, simulating the
        // directory round trip during which the user flips the setting off.
        final creation =
            Completer<Result<PayjoinReceiverSession, ReceiveFailure>>();
        when(
          () => receiveWithPayjoin.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
          ),
        ).thenAnswer((_) => creation.future);

        final bloc = buildBloc();
        addTearDown(bloc.close);

        bloc.add(const ReceiveBitcoinStarted(null));
        await Future<void>.delayed(Duration.zero);

        // Toggle off mid-flight, then let the stale creation resolve.
        bloc.add(const ReceivePayjoinSettingChanged(false));
        await Future<void>.delayed(Duration.zero);
        creation.complete(Ok(_receiver()));
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.payjoinGloballyEnabled, isFalse);
        expect(bloc.state.payjoin, isNull);
        verifyNever(() => watchPayjoin.execute(ids: any(named: 'ids')));
      },
    );

    test('does NOT create a payjoin receiver session for a wallet with no '
        'balance at all, even though payjoin is enabled globally — a '
        'payjoin proposal needs at least one UTXO to contribute', () async {
      final bloc = buildBloc(wallet: _testWallet(balanceSat: BigInt.zero));
      addTearDown(bloc.close);

      bloc.add(const ReceiveBitcoinStarted(null));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.payjoin, isNull);
      expect(bloc.state.payjoinGloballyEnabled, isTrue);
      expect(bloc.state.isPayjoinAwaitingFunds, isTrue);
      verifyNever(
        () => receiveWithPayjoin.execute(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
        ),
      );
    });

    test(
      'DOES create a payjoin receiver session for a wallet with ONLY '
      'unconfirmed balance (balanceSat > 0, confirmedBalanceSat == 0) — '
      'the contribution path draws from listUnspent which includes '
      'unconfirmed outputs, so waiting for a confirmation only delays '
      'payjoin activation on fresh wallets (product decision 2026-07-25)',
      () async {
        final createdPayjoin = _receiver();
        when(
          () => receiveWithPayjoin.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
          ),
        ).thenAnswer((_) async => Ok(createdPayjoin));
        final bloc = buildBloc(
          wallet: _testWallet(
            balanceSat: BigInt.from(50000),
            confirmedBalanceSat: BigInt.zero,
          ),
        );
        addTearDown(bloc.close);

        bloc.add(const ReceiveBitcoinStarted(null));
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.payjoin, createdPayjoin);
        expect(bloc.state.isPayjoinAwaitingFunds, isFalse);
      },
    );
  });

  group('payjoin reacts live to the global setting changing', () {
    test(
      'does not create duplicate sessions when persistence and watcher both emit enable',
      () async {
        when(() => getPayjoinPolicy.execute()).thenAnswer(
          (_) async => const Ok((enabled: false, minimumAmountSat: 10000)),
        );
        final creations =
            <Completer<Result<PayjoinReceiverSession, ReceiveFailure>>>[];
        when(
          () => receiveWithPayjoin.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
          ),
        ).thenAnswer((_) {
          final creation =
              Completer<Result<PayjoinReceiverSession, ReceiveFailure>>();
          creations.add(creation);
          return creation.future;
        });

        final bloc = buildBloc();
        addTearDown(bloc.close);

        bloc.add(const ReceiveBitcoinStarted(null));
        await pumpEventQueue();
        expect(bloc.state.payjoin, isNull);

        bloc.add(ReceivePayjoinToggled(true, () async => true));
        await Future<void>.delayed(Duration.zero);
        payjoinEnabledChangeController.add(true);
        await pumpEventQueue();

        expect(creations, hasLength(1));
        creations.single.complete(Ok(_receiver()));
        await pumpEventQueue();

        verify(() => watchPayjoin.execute(ids: any(named: 'ids'))).called(1);
      },
    );

    test(
      'does not create duplicate sessions when watcher emits before persistence',
      () async {
        when(() => getPayjoinPolicy.execute()).thenAnswer(
          (_) async => const Ok((enabled: false, minimumAmountSat: 10000)),
        );
        final creations =
            <Completer<Result<PayjoinReceiverSession, ReceiveFailure>>>[];
        when(
          () => receiveWithPayjoin.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
          ),
        ).thenAnswer((_) {
          final creation =
              Completer<Result<PayjoinReceiverSession, ReceiveFailure>>();
          creations.add(creation);
          return creation.future;
        });

        final bloc = buildBloc();
        addTearDown(bloc.close);

        bloc.add(const ReceiveBitcoinStarted(null));
        await pumpEventQueue();
        payjoinEnabledChangeController.add(true);
        await Future<void>.delayed(Duration.zero);
        bloc.add(ReceivePayjoinToggled(true, () async => true));
        await pumpEventQueue();

        expect(creations, hasLength(1));
        creations.single.complete(Ok(_receiver()));
        await pumpEventQueue();
      },
    );

    test('creates a payjoin receiver session as soon as the setting is '
        'flipped on, without needing to leave and re-enter the receive '
        'screen', () async {
      when(() => getPayjoinPolicy.execute()).thenAnswer(
        (_) async => const Ok((enabled: false, minimumAmountSat: 10000)),
      );
      final createdPayjoin = _receiver();
      when(
        () => receiveWithPayjoin.execute(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
        ),
      ).thenAnswer((_) async => Ok(createdPayjoin));

      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const ReceiveBitcoinStarted(null));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.payjoin, isNull);

      payjoinEnabledChangeController.add(true);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.payjoinGloballyEnabled, isTrue);
      expect(bloc.state.payjoin, createdPayjoin);
    });

    test('clears an existing payjoin receiver session as soon as the '
        'setting is flipped off', () async {
      final createdPayjoin = _receiver();
      when(
        () => receiveWithPayjoin.execute(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
        ),
      ).thenAnswer((_) async => Ok(createdPayjoin));

      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const ReceiveBitcoinStarted(null));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.payjoin, createdPayjoin);

      payjoinEnabledChangeController.add(false);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.payjoinGloballyEnabled, isFalse);
      expect(bloc.state.payjoin, isNull);
    });

    test('does NOT create a session on enable if the wallet still has no '
        'balance', () async {
      when(() => getPayjoinPolicy.execute()).thenAnswer(
        (_) async => const Ok((enabled: false, minimumAmountSat: 10000)),
      );

      final bloc = buildBloc(wallet: _testWallet(balanceSat: BigInt.zero));
      addTearDown(bloc.close);

      bloc.add(const ReceiveBitcoinStarted(null));
      await Future<void>.delayed(Duration.zero);

      payjoinEnabledChangeController.add(true);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.payjoinGloballyEnabled, isTrue);
      expect(bloc.state.payjoin, isNull);
      expect(bloc.state.isPayjoinAwaitingFunds, isTrue);
      verifyNever(
        () => receiveWithPayjoin.execute(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
        ),
      );
    });
  });

  group('live payjoin minimum', () {
    test(
      'updates the open receive state without recreating its session',
      () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);
        bloc.add(const ReceiveBitcoinStarted(null));
        await Future<void>.delayed(Duration.zero);

        payjoinMinAmountChangeController.add(50000);
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.payjoinMinAmountSat, 50000);
        verify(
          () => receiveWithPayjoin.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
          ),
        ).called(1);
      },
    );
  });

  group('idle receiver expiry', () {
    test(
      'rotates to a fresh receiver instead of surfacing a payment timeout',
      () async {
        final first = _receiver(id: 'first');
        final second = _receiver(id: 'second');
        final third = _receiver(id: 'third');
        var creations = 0;
        when(
          () => receiveWithPayjoin.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
          ),
        ).thenAnswer((_) async {
          creations++;
          return switch (creations) {
            1 => Ok(first),
            2 => Ok(second),
            _ => Ok(third),
          };
        });
        final bloc = buildBloc();
        addTearDown(bloc.close);
        bloc.add(const ReceiveBitcoinStarted(null));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.payjoin?.id, 'first');

        bloc.add(
          ReceivePayjoinUpdated(
            _receiver(id: 'first', status: PayjoinStatus.expired),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.payjoin?.id, 'second');
        expect(bloc.state.isPayjoinFlowOwningNavigation, isFalse);

        bloc.add(
          ReceivePayjoinUpdated(
            _receiver(id: 'second', status: PayjoinStatus.expired),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.payjoin?.id, 'third');
        expect(creations, 3);
      },
    );
  });

  group('optional receive details', () {
    test('clearing an optional on-chain amount restores null', () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const ReceiveBitcoinStarted(null));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const ReceiveAmountInputChanged('1000'));
      bloc.add(const ReceiveAmountConfirmed());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.confirmedAmountSat, 1000);

      bloc.add(const ReceiveAmountInputChanged(''));
      bloc.add(const ReceiveAmountConfirmed());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.confirmedAmountSat, isNull);
    });

    test('clearing a message removes its persisted address label', () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const ReceiveBitcoinStarted(null));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const ReceiveNoteChanged(''));
      bloc.add(const ReceiveNoteSaved());
      await Future<void>.delayed(Duration.zero);

      // An empty note must reach the use-case as an empty note — that is what
      // makes it a delete rather than a store. The trash-vs-store decision
      // itself now lives in SaveReceiveAddressLabelUsecase and is covered by
      // its own test.
      verify(
        () => saveAddressLabel.execute(
          address: 'bc1qtest',
          walletId: any(named: 'walletId'),
          note: '',
        ),
      ).called(1);
    });

    test('a failed note save surfaces a sanitized failure', () async {
      when(
        () => saveAddressLabel.execute(
          address: any(named: 'address'),
          walletId: any(named: 'walletId'),
          note: any(named: 'note'),
        ),
      ).thenAnswer(
        (_) async => const Err(
          ReceiveNoteNotSavedFailure('drift: UNIQUE constraint failed'),
        ),
      );

      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const ReceiveBitcoinStarted(null));
      await pumpEventQueue();

      bloc.add(const ReceiveNoteChanged('dinner'));
      bloc.add(const ReceiveNoteSaved());
      await pumpEventQueue();

      expect(bloc.state.failure, isA<ReceiveNoteNotSavedFailure>());
    });
  });

  // _onAmountCurrencyChanged had no try/catch before this migration and
  // called two throwing use-cases, so a failed rate fetch escaped the handler
  // as an unhandled bloc error. These pin the Err path that replaced it.
  group('amount currency change', () {
    test('a failed rate fetch surfaces a failure instead of escaping the '
        'handler', () async {
      when(
        () => convertSatsToCurrency.execute(
          amountSat: any(named: 'amountSat'),
          currencyCode: any(named: 'currencyCode'),
        ),
      ).thenAnswer(
        (_) async => const Err(ReceiveUnexpectedFailure('exchange 503')),
      );

      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const ReceiveBitcoinStarted(null));
      await pumpEventQueue();

      bloc.add(const ReceiveAmountCurrencyChanged('USD'));
      await pumpEventQueue();

      expect(bloc.state.failure, isA<ReceiveUnexpectedFailure>());
      // The currency is NOT switched: without a rate the amount field would
      // convert against a stale or zero rate.
      expect(bloc.state.inputAmountCurrencyCode, isNot('USD'));
    });

    test(
      'a fiat amount too large to represent is rejected, not converted',
      () async {
        // A long enough digit string parses to double.infinity, and
        // fiatToSats would reach (infinity * 1e8).round(), which throws
        // UnsupportedError with no try/catch left above it.
        final bloc = buildBloc();
        addTearDown(bloc.close);
        bloc.add(const ReceiveBitcoinStarted(null));
        await pumpEventQueue();

        bloc.add(ReceiveAmountCurrencyChanged('USD'));
        await pumpEventQueue();
        bloc.add(ReceiveAmountInputChanged('9' * 309));
        await pumpEventQueue();

        expect(
          bloc.state.failure,
          isA<ReceiveAmountAboveProtocolLimitFailure>(),
        );
        expect(bloc.state.hasAmountInputFailure, isTrue);
      },
    );

    test('switches currency and rate on success', () async {
      when(
        () => convertSatsToCurrency.execute(
          amountSat: any(named: 'amountSat'),
          currencyCode: any(named: 'currencyCode'),
        ),
      ).thenAnswer((_) async => const Ok(0.5));

      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const ReceiveBitcoinStarted(null));
      await pumpEventQueue();

      bloc.add(const ReceiveAmountCurrencyChanged('USD'));
      await pumpEventQueue();

      expect(bloc.state.inputAmountCurrencyCode, 'USD');
      expect(bloc.state.fiatCurrencyCode, 'USD');
      expect(bloc.state.exchangeRate, 0.5);
      expect(bloc.state.failure, isNull);
    });

    test('switching back to a bitcoin unit restores the settings currency, '
        'and a failure there is surfaced too', () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const ReceiveBitcoinStarted(null));
      await pumpEventQueue();

      when(() => getSettings.execute()).thenAnswer(
        (_) async => const Err(ReceiveUnexpectedFailure('prefs unreadable')),
      );

      bloc.add(ReceiveAmountCurrencyChanged(BitcoinUnit.sats.code));
      await pumpEventQueue();

      expect(bloc.state.failure, isA<ReceiveUnexpectedFailure>());
    });
  });

  test('ignores an in-flight order swap update after close', () async {
    final record = _receiveOrderSwapRecord();
    final lateStream = _LateOrderSwapStream();
    when(
      () => createOrderSwap.execute(
        wallet: any(named: 'wallet'),
        amountSat: 1000,
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) async => Ok(record));
    when(
      () => watchOrderSwap.execute(record.localId),
    ).thenAnswer((_) => lateStream);
    final bloc = buildBloc(wallet: _testWallet(network: Network.liquidTestnet));

    bloc.add(const ReceiveLightningStarted());
    await pumpEventQueue();
    bloc.add(const ReceiveAmountInputChanged('1000'));
    bloc.add(const ReceiveAmountConfirmed());
    await pumpEventQueue();
    await bloc.close();

    expect(() => lateStream.emit(record), returnsNormally);
  });

  test(
    'ignores a second Lightning confirmation while creation is in flight',
    () async {
      final creation = Completer<Result<OrderSwapRecord, ReceiveFailure>>();
      when(
        () => createOrderSwap.execute(
          wallet: any(named: 'wallet'),
          amountSat: 1000,
          note: any(named: 'note'),
        ),
      ).thenAnswer((_) => creation.future);
      final bloc = buildBloc(
        wallet: _testWallet(network: Network.liquidTestnet),
      );
      addTearDown(bloc.close);

      bloc.add(const ReceiveLightningStarted());
      await pumpEventQueue();
      bloc.add(const ReceiveAmountInputChanged('1000'));
      bloc.add(const ReceiveAmountConfirmed());
      await pumpEventQueue();
      bloc.add(const ReceiveAmountConfirmed());
      await pumpEventQueue();

      verify(
        () => createOrderSwap.execute(
          wallet: any(named: 'wallet'),
          amountSat: 1000,
          note: any(named: 'note'),
        ),
      ).called(1);
      creation.complete(const Err(ReceiveSwapUnavailableFailure()));
    },
  );

  group('preselected-wallet network guard', () {
    // The preselected wallet survives tab switches (the shell's bloc is
    // created once), so a receive entered from a liquid wallet must not
    // carry that wallet into the bitcoin flow — its balance would drive the
    // payjoin gates and its id the generated address.
    test('a liquid preselected wallet never becomes the bitcoin flow wallet '
        '— the default bitcoin wallet is used instead', () async {
      final liquidWallet = _testWallet(
        origin: 'liquid-w',
        network: Network.liquidMainnet,
        balanceSat: BigInt.from(900000),
      );
      final bloc = buildBloc(wallet: liquidWallet);
      addTearDown(bloc.close);

      bloc.add(const ReceiveBitcoinStarted(null));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.wallet?.origin, 'default-btc');
      expect(bloc.state.wallet?.isBitcoin, isTrue);
    });

    test('payjoin gates read the bitcoin wallet balance, not the funded '
        'liquid wallet the flow was entered with', () async {
      when(() => getWallets.execute(onlyBitcoin: true)).thenAnswer(
        (_) async =>
            Ok([_testWallet(origin: 'default-btc', balanceSat: BigInt.zero)]),
      );
      final liquidWallet = _testWallet(
        origin: 'liquid-w',
        network: Network.liquidMainnet,
        balanceSat: BigInt.from(900000),
      );
      final bloc = buildBloc(wallet: liquidWallet);
      addTearDown(bloc.close);

      bloc.add(const ReceiveBitcoinStarted(null));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.hasUtxos, isFalse);
      expect(bloc.state.isPayjoinToggleable, isFalse);
    });
  });

  group('payjoin badge toggle (ReceivePayjoinToggled)', () {
    test('persists the new value to the global setting', () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const ReceiveBitcoinStarted(null));
      await Future<void>.delayed(Duration.zero);

      bloc.add(ReceivePayjoinToggled(false, () async => true));
      await Future<void>.delayed(Duration.zero);

      verify(
        () => setPayjoinEnabled.execute(
          false,
          requestConsent: any(named: 'requestConsent'),
        ),
      ).called(1);
    });

    test(
      'updates the QR immediately when disabling payjoin without a watcher event',
      () async {
        when(
          () => setPayjoinEnabled.execute(
            false,
            requestConsent: any(named: 'requestConsent'),
          ),
        ).thenAnswer((_) async => const Ok<bool, ReceiveFailure>(false));

        final cancel = Completer<void>();
        addTearDown(() {
          if (!cancel.isCompleted) cancel.complete();
        });
        when(
          () => watchPayjoin.execute(ids: any(named: 'ids')),
        ).thenAnswer((_) => _ControlledCancelPayjoinStream(cancel.future));

        final bloc = buildBloc();
        addTearDown(bloc.close);

        bloc.add(const ReceiveBitcoinStarted(null));
        await pumpEventQueue();
        expect(bloc.state.qrData, contains('pj='));

        bloc.add(ReceivePayjoinToggled(false, () async => true));
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.payjoinGloballyEnabled, isFalse);
        expect(bloc.state.payjoin, isNull);
        expect(
          Uri.parse(bloc.state.qrData).queryParameters,
          isNot(contains('pj')),
        );

        cancel.complete();
      },
    );

    test(
      'drops repeated toggles while consent and persistence are in flight',
      () async {
        final pending = Completer<Result<bool, ReceiveFailure>>();
        when(
          () => setPayjoinEnabled.execute(
            any(),
            requestConsent: any(named: 'requestConsent'),
          ),
        ).thenAnswer((_) => pending.future);
        final bloc = buildBloc();
        addTearDown(bloc.close);

        bloc.add(ReceivePayjoinToggled(true, () async => true));
        await Future<void>.delayed(Duration.zero);
        bloc.add(ReceivePayjoinToggled(false, () async => true));
        await Future<void>.delayed(Duration.zero);

        verify(
          () => setPayjoinEnabled.execute(
            true,
            requestConsent: any(named: 'requestConsent'),
          ),
        ).called(1);
        verifyNever(
          () => setPayjoinEnabled.execute(
            false,
            requestConsent: any(named: 'requestConsent'),
          ),
        );

        pending.complete(const Ok<bool, ReceiveFailure>(true));
        await Future<void>.delayed(Duration.zero);
      },
    );

    test('isPayjoinToggleable is true for a funded, locally-signing bitcoin '
        'wallet and false for an empty one', () async {
      final funded = buildBloc();
      addTearDown(funded.close);
      funded.add(const ReceiveBitcoinStarted(null));
      await Future<void>.delayed(Duration.zero);
      expect(funded.state.isPayjoinToggleable, isTrue);

      final empty = buildBloc(wallet: _testWallet(balanceSat: BigInt.zero));
      addTearDown(empty.close);
      empty.add(const ReceiveBitcoinStarted(null));
      await Future<void>.delayed(Duration.zero);
      expect(empty.state.isPayjoinToggleable, isFalse);
    });
  });
}

OrderSwapRecord _receiveOrderSwapRecord() => OrderSwapRecord(
  localId: 'local-1',
  purpose: OrderSwapPurpose.receiveLightning,
  environment: OrderSwapEnvironment.testnet,
  inNetwork: OrderSwapNetwork.lightning,
  outNetwork: OrderSwapNetwork.liquid,
  isInAmountFixed: true,
  requestedAmountSat: BigInt.from(1000),
  destinationWalletId: 'w1',
  destination: 'tlq1destination',
  fallback: 'tlq1destination',
  order: OrderSwap(
    orderId: 'order-1',
    orderNumber: 1,
    inNetwork: OrderSwapNetwork.lightning,
    outNetwork: OrderSwapNetwork.liquid,
    payinAmountSat: BigInt.from(1000),
    payoutAmountSat: BigInt.from(900),
    payinCurrency: 'BTCLN',
    payoutCurrency: 'LBTC',
    payinMethod: 'Lightning',
    payoutMethod: 'Liquid',
    orderType: 'Swap',
    orderStatus: 'In_pending',
    payinStatus: 'Awaiting payment',
    payoutStatus: 'Not started',
    messageCode: 'PAYMENT_NOT_DETECTED',
    lightningInvoice: 'lntb-invoice',
    liquidAddress: 'tlq1destination',
    createdAt: DateTime.utc(2026),
    confirmationDeadline: DateTime.utc(2026, 1, 1, 0, 5),
  ),
  createdAt: DateTime.utc(2026),
  localStatus: OrderSwapLocalStatus.awaitingUserConfirmation,
);
