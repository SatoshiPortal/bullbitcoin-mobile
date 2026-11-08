import 'dart:async';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
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
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;

class _MockGetReceiveWalletsUsecase extends Mock
    implements GetReceiveWalletsUsecase {}

class _MockGetReceiveSettingsUsecase extends Mock
    implements GetReceiveSettingsUsecase {}

class _MockConvertReceiveAmountUsecase extends Mock
    implements ConvertReceiveAmountUsecase {}

class _MockPrepareReceiveAddressUsecase extends Mock
    implements PrepareReceiveAddressUsecase {}

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
  DateTime? fallbackAvailableAt,
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
  fallbackAvailableAt: fallbackAvailableAt,
);

class _MockTransactions extends Mock implements WalletTransactionRepository {}

void main() {
  late _MockGetReceiveWalletsUsecase getWallets;
  late _MockGetReceiveSettingsUsecase getSettings;
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

  ReceiveBloc buildBloc({
    Wallet? wallet,
    bool withPresetWallet = true,
    WatchWalletTransactionByAddressUsecase? observation,
  }) => ReceiveBloc(
    getReceiveWalletsUsecase: getWallets,
    getReceiveSettingsUsecase: getSettings,
    convertReceiveAmountUsecase: convertSatsToCurrency,
    prepareReceiveAddressUsecase: getReceiveAddress,
    createReceiveOrderSwapUsecase: createOrderSwap,
    receiveWithPayjoinUsecase: receiveWithPayjoin,
    broadcastOriginalTransactionUsecase: broadcastOriginalTransaction,
    watchPayjoinUsecase: watchPayjoin,
    watchWalletTransactionByAddressUsecase:
        observation ?? watchWalletTransaction,
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

    test('waits for the sender after a proposal before offering the '
        'fallback', () async {
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
      final proposedPayjoin = _receiver(
        status: PayjoinStatus.proposed,
        originalTxBytes: Uint8List.fromList([1, 2, 3]),
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
        fallbackAvailableAt: clock.now().add(const Duration(seconds: 60)),
      );
      when(
        () => broadcastOriginalTransaction.execute(any()),
      ).thenAnswer((_) async => Ok(proposedPayjoin));

      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const ReceiveBitcoinStarted(null));
      await Future<void>.delayed(Duration.zero);

      bloc.add(ReceivePayjoinUpdated(proposedPayjoin));
      await Future<void>.delayed(Duration.zero);

      // The sender normally broadcasts the payjoin within seconds.
      expect(bloc.state.isWaitingForPayjoinSender, isTrue);
      expect(bloc.state.canOfferPayjoinFallback, isFalse);
      bloc.add(const ReceivePayjoinOriginalTxBroadcasted());
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => broadcastOriginalTransaction.execute(any()));
    });

    test('reopening a proposed session keeps only its remaining wait', () {
      fakeAsync((async) {
        final session = _receiver(
          status: PayjoinStatus.proposed,
          originalTxBytes: Uint8List.fromList([1, 2, 3]),
          proposalPsbt: 'proposal',
          fallbackAvailableAt: clock.now().add(const Duration(seconds: 20)),
        );
        when(
          () => receiveWithPayjoin.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
          ),
        ).thenAnswer((_) async => Ok(session));
        final bloc = buildBloc();
        bloc.add(const ReceiveBitcoinStarted(null));
        async.flushMicrotasks();
        expect(bloc.state.isWaitingForPayjoinSender, isTrue);
        async.elapse(const Duration(seconds: 19));
        expect(bloc.state.isWaitingForPayjoinSender, isTrue);
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(bloc.state.isWaitingForPayjoinSender, isFalse);
        bloc.close();
        async.flushMicrotasks();
      });
    });

    test('the real sender timer expires after 60 seconds', () {
      fakeAsync((async) {
        final bloc = buildBloc();
        bloc.add(const ReceiveBitcoinStarted(null));
        async.flushMicrotasks();
        bloc.add(
          ReceivePayjoinUpdated(
            _receiver(
              status: PayjoinStatus.proposed,
              originalTxBytes: Uint8List.fromList([1, 2, 3]),
              proposalPsbt: 'proposal',
              fallbackAvailableAt: clock.now().add(const Duration(seconds: 60)),
            ),
          ),
        );
        async.flushMicrotasks();
        expect(bloc.state.isWaitingForPayjoinSender, isTrue);
        async.elapse(const Duration(seconds: 59));
        expect(bloc.state.canOfferPayjoinFallback, isFalse);
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(bloc.state.isWaitingForPayjoinSender, isFalse);
        expect(bloc.state.canOfferPayjoinFallback, isTrue);
        bloc.close();
        async.flushMicrotasks();
      });
    });

    test('a timer that fires before the wall-clock deadline rearms', () {
      fakeAsync((async) {
        final bloc = buildBloc();
        bloc.add(const ReceiveBitcoinStarted(null));
        async.flushMicrotasks();
        bloc.add(
          ReceivePayjoinUpdated(
            _receiver(
              status: PayjoinStatus.proposed,
              originalTxBytes: Uint8List.fromList([1, 2, 3]),
              proposalPsbt: 'proposal',
              fallbackAvailableAt: clock.now().add(const Duration(seconds: 60)),
            ),
          ),
        );
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 50));
        // The monotonic timer can run ahead of the wall clock.
        bloc.add(const ReceivePayjoinSenderWaitElapsed('pj1'));
        async.flushMicrotasks();
        expect(bloc.state.isWaitingForPayjoinSender, isTrue);
        expect(bloc.state.canOfferPayjoinFallback, isFalse);
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();
        expect(bloc.state.isWaitingForPayjoinSender, isFalse);
        expect(bloc.state.canOfferPayjoinFallback, isTrue);
        bloc.close();
        async.flushMicrotasks();
      });
    });

    for (final resolvedStatus in [
      PayjoinStatus.completed,
      PayjoinStatus.aborted,
    ]) {
      test('resolution to $resolvedStatus cancels the sender timer', () {
        fakeAsync((async) {
          final bloc = buildBloc();
          bloc.add(const ReceiveBitcoinStarted(null));
          async.flushMicrotasks();
          bloc.add(
            ReceivePayjoinUpdated(
              _receiver(
                status: PayjoinStatus.proposed,
                originalTxBytes: Uint8List.fromList([1, 2, 3]),
                proposalPsbt: 'proposal',
                fallbackAvailableAt: clock.now().add(
                  const Duration(seconds: 60),
                ),
              ),
            ),
          );
          async.flushMicrotasks();
          expect(bloc.state.isWaitingForPayjoinSender, isTrue);
          bloc.add(ReceivePayjoinUpdated(_receiver(status: resolvedStatus)));
          async.flushMicrotasks();
          expect(bloc.state.isWaitingForPayjoinSender, isFalse);
          expect(async.nonPeriodicTimerCount, 0);
          bloc.close();
          async.flushMicrotasks();
        });
      });
    }

    test('changing the address clears the wait and cancels its timer', () {
      when(
        () => getReceiveAddress.execute(
          walletId: any(named: 'walletId'),
          generateNew: true,
        ),
      ).thenAnswer((_) async => const Err(ReceiveAddressUnavailableFailure()));
      fakeAsync((async) {
        final bloc = buildBloc();
        bloc.add(const ReceiveBitcoinStarted(null));
        async.flushMicrotasks();
        bloc.add(
          ReceivePayjoinUpdated(
            _receiver(
              status: PayjoinStatus.proposed,
              originalTxBytes: Uint8List.fromList([1, 2, 3]),
              proposalPsbt: 'proposal',
              fallbackAvailableAt: clock.now().add(const Duration(seconds: 60)),
            ),
          ),
        );
        async.flushMicrotasks();
        expect(bloc.state.isWaitingForPayjoinSender, isTrue);
        bloc.add(const ReceiveNewAddressGenerated());
        async.flushMicrotasks();
        expect(bloc.state.isWaitingForPayjoinSender, isFalse);
        expect(async.nonPeriodicTimerCount, 0);
        bloc.close();
        async.flushMicrotasks();
      });
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
  group('no price', () {
    test('receiving works on, with no fiat value and no failure', () async {
      when(
        () => convertSatsToCurrency.execute(
          amountSat: any(named: 'amountSat'),
          currencyCode: any(named: 'currencyCode'),
        ),
      ).thenAnswer((_) async => const Err(ReceivePriceUnavailableFailure()));

      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const ReceiveBitcoinStarted(null));
      await pumpEventQueue();

      expect(bloc.state.failure, isNull);
      expect(bloc.state.exchangeRate, isNull);
      expect(bloc.state.inputAmountCurrencyCodes, [
        BitcoinUnit.btc.code,
        BitcoinUnit.sats.code,
      ]);
      verify(
        () => watchWalletTransaction.execute(
          walletId: any(named: 'walletId'),
          toAddress: any(named: 'toAddress'),
        ),
      ).called(1);
    });
  });

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

    test('a currency whose price does not come is not taken', () async {
      when(
        () => convertSatsToCurrency.execute(
          amountSat: any(named: 'amountSat'),
          currencyCode: any(named: 'currencyCode'),
        ),
      ).thenAnswer((_) async => const Err(ReceivePriceUnavailableFailure()));

      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const ReceiveBitcoinStarted(null));
      await pumpEventQueue();

      bloc.add(const ReceiveAmountCurrencyChanged('USD'));
      await pumpEventQueue();

      // A fiat amount with no price would request zero sats.
      expect(bloc.state.inputAmountCurrencyCode, isNot('USD'));
    });

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
    'ignores duplicate Lightning confirmation and permits it after reselection',
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
      bloc.add(const ReceiveBitcoinStarted(null));
      await pumpEventQueue();
      bloc.add(const ReceiveLightningStarted());
      await pumpEventQueue();
      creation.complete(const Err(ReceiveSwapUnavailableFailure()));
      await pumpEventQueue();
      expect(bloc.state.creatingSwap, isFalse);
      expect(bloc.state.failure, isNull);
      bloc.add(const ReceiveAmountInputChanged('1000'));
      bloc.add(const ReceiveAmountConfirmed());
      await pumpEventQueue();
      verify(
        () => createOrderSwap.execute(
          wallet: any(named: 'wallet'),
          amountSat: 1000,
          note: any(named: 'note'),
        ),
      ).called(1);
    },
  );

  test(
    'Liquid new address uses the persistent writer and survives reopen',
    () async {
      final wallet = _testWallet(network: Network.liquidMainnet);
      final next = _testAddress().copyWith(index: 1, address: 'liquid-next');
      var issued = _testAddress();
      when(
        () => getReceiveAddress.execute(walletId: wallet.id),
      ).thenAnswer((_) async => Ok(issued));
      when(
        () => getReceiveAddress.execute(walletId: wallet.id, generateNew: true),
      ).thenAnswer((_) async {
        issued = next;
        return Ok(issued);
      });
      final bloc = buildBloc(wallet: wallet);
      bloc.add(const ReceiveLiquidStarted());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.liquidAddress, issued);
      bloc.add(const ReceiveNewAddressGenerated());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.liquidAddress, next);
      verify(
        () => getReceiveAddress.execute(walletId: wallet.id, generateNew: true),
      ).called(1);
      await bloc.close();
      final reopened = buildBloc(wallet: wallet);
      addTearDown(reopened.close);
      reopened.add(const ReceiveLiquidStarted());
      await Future<void>.delayed(Duration.zero);
      expect(reopened.state.liquidAddress, next);
    },
  );

  for (final network in [Network.bitcoinMainnet, Network.liquidMainnet]) {
    test(
      '$network retry retains new-address intent and drops duplicates',
      () async {
        final wallet = _testWallet(network: network);
        final old = _testAddress();
        final next = old.copyWith(index: 1, address: 'next-issued');
        final retry = Completer<Result<WalletAddress, ReceiveFailure>>();
        var advances = 0;
        when(
          () => getReceiveAddress.execute(walletId: wallet.id),
        ).thenAnswer((_) async => Ok(old));
        when(
          () =>
              getReceiveAddress.execute(walletId: wallet.id, generateNew: true),
        ).thenAnswer((_) async {
          if (++advances == 1) {
            return const Err(ReceiveAddressUnavailableFailure());
          }
          return retry.future;
        });
        final bloc = buildBloc(wallet: wallet);
        addTearDown(bloc.close);
        final start = wallet.isBitcoin
            ? const ReceiveBitcoinStarted(null)
            : const ReceiveLiquidStarted();
        WalletAddress? address() => wallet.isBitcoin
            ? bloc.state.bitcoinAddress
            : bloc.state.liquidAddress;
        bloc.add(start);
        await pumpEventQueue();
        expect(address(), old);
        bloc.add(const ReceiveNewAddressGenerated());
        await pumpEventQueue();
        expect(bloc.state.failure, isA<ReceiveAddressUnavailableFailure>());
        expect(address(), isNull);
        bloc.add(start);
        await pumpEventQueue();
        bloc.add(start);
        bloc.add(const ReceiveNewAddressGenerated());
        await pumpEventQueue();
        retry.complete(Ok(next));
        await pumpEventQueue();
        expect(address(), next);
        expect(bloc.state.wallet?.id, wallet.id);
        expect(bloc.state.failure, isNull);
        expect(advances, 2);
        verify(() => getReceiveAddress.execute(walletId: wallet.id)).called(1);
      },
    );

    test('$network initial-open retry reuses the unused address', () async {
      final wallet = _testWallet(network: network);
      var attempts = 0;
      when(() => getReceiveAddress.execute(walletId: wallet.id)).thenAnswer(
        (_) async => ++attempts == 1
            ? const Err(ReceiveAddressUnavailableFailure())
            : Ok(_testAddress()),
      );
      final bloc = buildBloc(wallet: wallet);
      addTearDown(bloc.close);
      final start = wallet.isBitcoin
          ? const ReceiveBitcoinStarted(null)
          : const ReceiveLiquidStarted();
      bloc.add(start);
      await pumpEventQueue();
      expect(bloc.state.failure, isA<ReceiveAddressUnavailableFailure>());
      bloc.add(start);
      await pumpEventQueue();
      expect(
        wallet.isBitcoin ? bloc.state.bitcoinAddress : bloc.state.liquidAddress,
        _testAddress(),
      );
      expect(bloc.state.failure, isNull);
      verifyNever(
        () => getReceiveAddress.execute(walletId: wallet.id, generateNew: true),
      );
    });
  }

  for (final network in [Network.bitcoinMainnet, Network.liquidMainnet]) {
    for (final succeeds in [true, false]) {
      test(
        '$network navigation while advance pending success=$succeeds',
        () async {
          final wallet = _testWallet(network: network);
          final destination = _testWallet(
            origin: 'destination',
            network: wallet.isBitcoin
                ? Network.liquidMainnet
                : Network.bitcoinMainnet,
          );
          final pending = Completer<Result<WalletAddress, ReceiveFailure>>();
          when(
            () => getWallets.execute(onlyLiquid: true, onlyDefaults: true),
          ).thenAnswer((_) async => Ok([destination]));
          when(
            () => getWallets.execute(onlyBitcoin: true),
          ).thenAnswer((_) async => Ok([destination]));
          when(
            () => getReceiveAddress.execute(
              walletId: wallet.id,
              generateNew: true,
            ),
          ).thenAnswer((_) => pending.future);
          final bloc = buildBloc(wallet: wallet);
          addTearDown(bloc.close);
          bloc.add(
            wallet.isBitcoin
                ? const ReceiveBitcoinStarted(null)
                : const ReceiveLiquidStarted(),
          );
          await pumpEventQueue();
          bloc.add(const ReceiveNewAddressGenerated());
          await pumpEventQueue();
          bloc.add(
            wallet.isBitcoin
                ? const ReceiveLiquidStarted()
                : const ReceiveBitcoinStarted(null),
          );
          await pumpEventQueue();
          expect(bloc.state.wallet?.id, destination.id);
          expect(
            bloc.state.type,
            wallet.isBitcoin ? ReceiveType.liquid : ReceiveType.bitcoin,
          );
          final afterNavigation = bloc.state;
          pending.complete(
            succeeds
                ? Ok(_testAddress().copyWith(index: 1, address: 'late-issued'))
                : const Err(ReceiveAddressUnavailableFailure()),
          );
          await pumpEventQueue();
          expect(bloc.state, afterNavigation);
        },
      );
    }
  }

  test('wallet navigation retains current payjoin subscription', () async {
    final walletA = _testWallet(origin: 'wallet-a');
    final walletB = _testWallet(origin: 'wallet-b');
    final pending = Completer<Result<PayjoinReceiverSession, ReceiveFailure>>();
    final bUpdates =
        StreamController<Result<PayjoinSession, ReceiveFailure>>.broadcast();
    final bSession = _receiver(id: 'pj-b', walletId: walletB.id);
    var advances = 0;
    when(
      () => getReceiveAddress.execute(walletId: walletA.id, generateNew: true),
    ).thenAnswer(
      (_) async => ++advances == 1
          ? const Err(ReceiveAddressUnavailableFailure())
          : Ok(_testAddress().copyWith(index: 1, address: 'new-a')),
    );
    when(
      () => receiveWithPayjoin.execute(walletId: walletA.id, address: 'new-a'),
    ).thenAnswer((_) => pending.future);
    when(
      () => receiveWithPayjoin.execute(
        walletId: walletB.id,
        address: any(named: 'address'),
      ),
    ).thenAnswer((_) async => Ok(bSession));
    when(
      () => watchPayjoin.execute(ids: ['pj-b']),
    ).thenAnswer((_) => bUpdates.stream);
    final bloc = buildBloc(withPresetWallet: false);
    addTearDown(() async {
      await bloc.close();
      await bUpdates.close();
    });
    bloc.add(ReceiveBitcoinStarted(walletA));
    await pumpEventQueue();
    bloc.add(const ReceiveNewAddressGenerated());
    await pumpEventQueue();
    expect(bloc.state.failure, isA<ReceiveAddressUnavailableFailure>());
    bloc.add(ReceiveBitcoinStarted(walletA));
    await pumpEventQueue();
    expect(advances, 2);
    bloc.add(ReceiveBitcoinStarted(walletB));
    await pumpEventQueue();
    expect(bloc.state.wallet?.id, walletB.id);
    expect(bloc.state.payjoin?.id, 'pj-b');
    expect(bUpdates.hasListener, isTrue);
    pending.complete(Ok(_receiver(id: 'late-pj-a', walletId: walletA.id)));
    await pumpEventQueue();
    expect(bloc.state.wallet?.id, walletB.id);
    expect(bloc.state.payjoin?.id, 'pj-b');
    final bUpdate = _receiver(
      id: 'pj-b',
      walletId: walletB.id,
      status: PayjoinStatus.proposed,
    );
    bUpdates.add(Ok(bUpdate));
    await pumpEventQueue();
    expect(bloc.state.payjoin?.status, PayjoinStatus.proposed);
    expect(bUpdates.hasListener, isTrue);
  });

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
  for (final queued in [false, true]) {
    test(
      'wallet switch rejects a previous-wallet poll completion (queued=$queued)',
      () async {
        final walletA = _testWallet(origin: 'wallet-a');
        final walletB = _testWallet(origin: 'wallet-b');
        final aTransactions = StreamController<WalletTransaction>.broadcast(
          sync: true,
        );
        final bPayjoin =
            Completer<Result<PayjoinReceiverSession, ReceiveFailure>>();
        when(
          () => getWallets.execute(onlyBitcoin: true),
        ).thenAnswer((_) async => Ok([walletA, walletB]));
        when(
          () => watchWalletTransaction.execute(
            walletId: walletA.id,
            toAddress: any(named: 'toAddress'),
          ),
        ).thenAnswer((_) => aTransactions.stream);
        when(
          () => receiveWithPayjoin.execute(
            walletId: walletB.id,
            address: any(named: 'address'),
          ),
        ).thenAnswer((_) => bPayjoin.future);
        final bloc = buildBloc(withPresetWallet: false);
        addTearDown(() async {
          if (!bPayjoin.isCompleted) {
            bPayjoin.complete(Ok(_receiver(id: 'pj-b', walletId: walletB.id)));
          }
          await pumpEventQueue();
          await bloc.close();
          await aTransactions.close();
        });

        // Home -> Receive loads both wallets, allowing the actual dropdown change.
        bloc.add(const ReceiveBitcoinStarted(null));
        await pumpEventQueue();
        expect(bloc.state.wallets, hasLength(2));
        expect(bloc.state.wallet?.id, walletA.id);
        expect(aTransactions.hasListener, isTrue);
        expect(bloc.state.tx, isNull);

        final payment = WalletTransaction(
          walletId: walletA.id,
          network: walletA.network,
          direction: WalletTransactionDirection.incoming,
          status: WalletTransactionStatus.pending,
          txId: 'payment-for-a',
          amountSat: 1000,
          feeSat: 0,
          vsize: 100,
          inputs: const [],
          outputs: const [],
          isRbf: false,
        );

        // A's periodic native poll is already running when the dropdown selects B.
        // Native work finishes normally after the screen epoch changes; B's funded
        // Payjoin setup is still awaiting its ordinary asynchronous network result.
        bloc.add(ReceiveBitcoinStarted(walletB));
        if (queued) aTransactions.add(payment);
        await pumpEventQueue();
        expect(bloc.state.wallet?.id, walletB.id);
        expect(bloc.state.type, ReceiveType.bitcoin);
        expect(bloc.state.payjoinAttemptSettled, isFalse);
        verify(
          () => receiveWithPayjoin.execute(
            walletId: walletB.id,
            address: any(named: 'address'),
          ),
        ).called(1);

        // Also exercise a completion arriving after the selection was processed.
        if (!queued) aTransactions.add(payment);
        await pumpEventQueue();
        expect(bloc.state.wallet?.id, walletB.id);
        expect(
          bloc.state.tx,
          isNull,
          reason:
              'A must not trigger payment navigation using selected wallet B',
        );
        bloc.add(ReceiveBitcoinStarted(walletA));
        await pumpEventQueue();
        bPayjoin.complete(Ok(_receiver(id: 'pj-b', walletId: walletB.id)));
        await pumpEventQueue();
        expect(bloc.state.wallet?.id, walletA.id);
        verifyNever(
          () => watchWalletTransaction.execute(
            walletId: walletB.id,
            toAddress: any(named: 'toAddress'),
          ),
        );
        aTransactions.add(payment);
        await pumpEventQueue();
        expect(bloc.state.tx, payment);
      },
    );
  }
  for (final beforeObservation in [false, true]) {
    test(
      'reads persisted payment with real watcher (beforeObservation=$beforeObservation)',
      () async {
        final wallet = _testWallet();
        final address = _testAddress(walletId: wallet.id);
        final revisions = StreamController<WalletRevisionState>.broadcast();
        final facade = WalletFacade(revisions.stream);
        final transactions = _MockTransactions();
        final price = Completer<Result<double, ReceiveFailure>>();
        final payment = WalletTransaction(
          walletId: wallet.id,
          network: wallet.network,
          direction: WalletTransactionDirection.incoming,
          status: WalletTransactionStatus.confirmed,
          txId: 'confirmed-during-receive-preparation',
          amountSat: 1000,
          feeSat: 0,
          vsize: 100,
          inputs: const [],
          outputs: const [],
          isRbf: false,
        );
        var persistedPayments = beforeObservation
            ? [payment]
            : <WalletTransaction>[];
        var reads = 0;
        when(
          () => transactions.getWalletTransactions(
            walletId: wallet.id,
            toAddress: address.address,
          ),
        ).thenAnswer((_) async {
          reads++;
          return persistedPayments;
        });
        final observation = WatchWalletTransactionByAddressUsecase(
          walletTransactionRepository: transactions,
          walletFacade: facade,
        );
        when(
          () => getReceiveAddress.execute(walletId: wallet.id),
        ).thenAnswer((_) async => Ok(address));
        when(() => getPayjoinPolicy.execute()).thenAnswer(
          (_) async => const Ok((enabled: false, minimumAmountSat: 10000)),
        );
        when(
          () => convertSatsToCurrency.execute(),
        ).thenAnswer((_) => price.future);
        final bloc = buildBloc(wallet: wallet, observation: observation);
        addTearDown(() async {
          if (!price.isCompleted) price.complete(const Ok(1.0));
          await pumpEventQueue();
          await bloc.close();
          await revisions.close();
        });
        WalletRevisionState revision(int number) => WalletRevisionState(
          stamp: WalletRevision(
            key: WalletKey(id: wallet.id, network: BitcoinNetwork.mainnet),
            generation: 1,
            revision: number,
          ),
          lifecycle: WalletLifecycle.active,
        );

        bloc.add(ReceiveBitcoinStarted(wallet));
        await pumpEventQueue();
        expect(bloc.state.bitcoinAddress, address);
        expect(bloc.state.qrData, isNotEmpty);
        expect(bloc.state.payjoinAttemptSettled, isTrue);

        persistedPayments = [payment];
        revisions.add(revision(2));
        await pumpEventQueue();
        price.complete(const Ok(1.0));
        await pumpEventQueue();
        expect(revisions.hasListener, isTrue);

        await pumpEventQueue();
        final paymentAfterQuietPoll = bloc.state.tx;
        final readsAfterQuietPoll = reads;

        revisions.add(revision(4));
        await pumpEventQueue();
        expect(bloc.state.tx, payment);
        expect(reads, greaterThan(0));
        expect(
          paymentAfterQuietPoll,
          payment,
          reason:
              'A confirmed payment persisted during Receive setup must be observed even when subsequent polls are unchanged; reads=$readsAfterQuietPoll',
        );
      },
    );
  }
  for (final cancel in [false, true]) {
    test(
      'real watcher coalesces in-flight revisions (cancel=$cancel)',
      () async {
        final revisions = StreamController<WalletRevisionState>.broadcast();
        final transactions = _MockTransactions();
        final first = Completer<List<WalletTransaction>>();
        final payment = WalletTransaction(
          walletId: 'w1',
          network: Network.bitcoinMainnet,
          direction: WalletTransactionDirection.incoming,
          status: WalletTransactionStatus.confirmed,
          txId: 'payment',
          amountSat: 1000,
          feeSat: 0,
          vsize: 100,
          inputs: const [],
          outputs: const [],
          isRbf: false,
        );
        var reads = 0;
        when(
          () => transactions.getWalletTransactions(
            walletId: 'w1',
            toAddress: 'current',
          ),
        ).thenAnswer((_) {
          expect(revisions.hasListener, isTrue);
          reads++;
          return reads == 1 ? first.future : Future.value([payment]);
        });
        final received = <WalletTransaction>[];
        final subscription = WatchWalletTransactionByAddressUsecase(
          walletTransactionRepository: transactions,
          walletFacade: WalletFacade(revisions.stream),
        ).execute(walletId: 'w1', toAddress: 'current').listen(received.add);
        await pumpEventQueue();
        expect(reads, 1);
        for (var number = 1; number <= 3; number++) {
          revisions.add(
            WalletRevisionState(
              stamp: WalletRevision(
                key: WalletKey(id: 'w1', network: BitcoinNetwork.mainnet),
                generation: 1,
                revision: number,
              ),
              lifecycle: WalletLifecycle.active,
            ),
          );
        }
        await pumpEventQueue();
        expect(reads, 1);
        if (cancel) await subscription.cancel();
        first.complete([]);
        await pumpEventQueue();
        expect(reads, cancel ? 1 : 2);
        expect(received, cancel ? isEmpty : [payment]);
        await subscription.cancel();
        await revisions.close();
      },
    );
  }
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
