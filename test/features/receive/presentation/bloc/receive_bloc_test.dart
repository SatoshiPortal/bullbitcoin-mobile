import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/entities/signer_entity.dart' show SignerEntity;
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/settings/domain/watch_payjoin_enabled_changes_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_address_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/receive/domain/usecases/create_receive_swap_use_case.dart';
import 'package:bb_mobile/features/receive/domain/usecases/set_receive_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/watch_receive_payjoin_min_amount_usecase.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockGetAvailableCurrenciesUsecase extends Mock
    implements GetAvailableCurrenciesUsecase {}

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockConvertSatsToCurrencyAmountUsecase extends Mock
    implements ConvertSatsToCurrencyAmountUsecase {}

class _MockGetReceiveAddressUsecase extends Mock
    implements GetReceiveAddressUsecase {}

class _MockGetAddressAtIndexUsecase extends Mock
    implements GetAddressAtIndexUsecase {}

class _MockCreateReceiveSwapUsecase extends Mock
    implements CreateReceiveSwapUsecase {}

class _MockReceiveWithPayjoinUsecase extends Mock
    implements ReceiveWithPayjoinUsecase {}

class _MockBroadcastOriginalTransactionUsecase extends Mock
    implements BroadcastOriginalTransactionUsecase {}

class _MockWatchPayjoinUsecase extends Mock implements WatchPayjoinUsecase {}

class _MockWatchWalletTransactionByAddressUsecase extends Mock
    implements WatchWalletTransactionByAddressUsecase {}

class _MockWatchSwapUsecase extends Mock implements WatchSwapUsecase {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

class _MockLabel extends Mock implements Label {}

class _MockGetSwapLimitsUsecase extends Mock implements GetSwapLimitsUsecase {}

class _MockWatchPayjoinEnabledChangesUsecase extends Mock
    implements WatchPayjoinEnabledChangesUsecase {}

class _MockSetReceivePayjoinEnabledUsecase extends Mock
    implements SetReceivePayjoinEnabledUsecase {}

class _MockWatchReceivePayjoinMinAmountUsecase extends Mock
    implements WatchReceivePayjoinMinAmountUsecase {}

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
}) => Wallet(
  origin: origin,
  network: network,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
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

PayjoinReceiver _receiver({
  String id = 'pj1',
  String walletId = 'w1',
  Uint8List? originalTxBytes,
  String? proposalPsbt,
  PayjoinStatus status = PayjoinStatus.started,
}) =>
    Payjoin.receiver(
          status: status,
          id: id,
          isTestnet: false,
          walletId: walletId,
          pjUri: 'bitcoin:bc1qtest?pj=https://payjo.in',
          createdAt: DateTime(2026),
          expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
          originalTxBytes: originalTxBytes,
          proposalPsbt: proposalPsbt,
        )
        as PayjoinReceiver;

void main() {
  late _MockGetWalletsUsecase getWallets;
  late _MockGetSettingsUsecase getSettings;
  late _MockGetAvailableCurrenciesUsecase getAvailableCurrencies;
  late _MockConvertSatsToCurrencyAmountUsecase convertSatsToCurrency;
  late _MockGetReceiveAddressUsecase getReceiveAddress;
  late _MockReceiveWithPayjoinUsecase receiveWithPayjoin;
  late _MockBroadcastOriginalTransactionUsecase broadcastOriginalTransaction;
  late _MockWatchPayjoinUsecase watchPayjoin;
  late _MockWatchWalletTransactionByAddressUsecase watchWalletTransaction;
  late _MockLabelsFacade labels;
  late _MockWatchPayjoinEnabledChangesUsecase watchPayjoinEnabledChanges;
  late _MockSetReceivePayjoinEnabledUsecase setPayjoinEnabled;
  late _MockWatchReceivePayjoinMinAmountUsecase watchPayjoinMinAmount;
  late StreamController<bool> payjoinEnabledChangeController;
  late StreamController<int> payjoinMinAmountChangeController;

  setUpAll(() {
    registerFallbackValue(_receiver());
  });

  ReceiveBloc buildBloc({Wallet? wallet}) => ReceiveBloc(
    getWalletsUsecase: getWallets,
    getAvailableCurrenciesUsecase: getAvailableCurrencies,
    getSettingsUsecase: getSettings,
    convertSatsToCurrencyAmountUsecase: convertSatsToCurrency,
    getReceiveAddressUsecase: getReceiveAddress,
    getAddressAtIndexUsecase: _MockGetAddressAtIndexUsecase(),
    createReceiveSwapUsecase: _MockCreateReceiveSwapUsecase(),
    receiveWithPayjoinUsecase: receiveWithPayjoin,
    broadcastOriginalTransactionUsecase: broadcastOriginalTransaction,
    watchPayjoinUsecase: watchPayjoin,
    watchWalletTransactionByAddressUsecase: watchWalletTransaction,
    watchSwapUsecase: _MockWatchSwapUsecase(),
    labelsFacade: labels,
    getSwapLimitsUsecase: _MockGetSwapLimitsUsecase(),
    watchPayjoinEnabledChangesUsecase: watchPayjoinEnabledChanges,
    watchReceivePayjoinMinAmountUsecase: watchPayjoinMinAmount,
    setReceivePayjoinEnabledUsecase: setPayjoinEnabled,
    wallet: wallet ?? _testWallet(),
  );

  setUp(() {
    getWallets = _MockGetWalletsUsecase();
    when(
      () => getWallets.execute(onlyBitcoin: true),
    ).thenAnswer((_) async => [_testWallet(origin: 'default-btc')]);
    getSettings = _MockGetSettingsUsecase();
    getAvailableCurrencies = _MockGetAvailableCurrenciesUsecase();
    convertSatsToCurrency = _MockConvertSatsToCurrencyAmountUsecase();
    getReceiveAddress = _MockGetReceiveAddressUsecase();
    receiveWithPayjoin = _MockReceiveWithPayjoinUsecase();
    broadcastOriginalTransaction = _MockBroadcastOriginalTransactionUsecase();
    watchPayjoin = _MockWatchPayjoinUsecase();
    watchWalletTransaction = _MockWatchWalletTransactionByAddressUsecase();
    labels = _MockLabelsFacade();
    watchPayjoinEnabledChanges = _MockWatchPayjoinEnabledChangesUsecase();
    payjoinEnabledChangeController = StreamController<bool>.broadcast();
    payjoinMinAmountChangeController = StreamController<int>.broadcast();
    when(
      () => watchPayjoinEnabledChanges.execute(),
    ).thenAnswer((_) => payjoinEnabledChangeController.stream);
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
    ).thenAnswer((_) async => const Ok<bool, SettingsFailure>(true));

    // Payjoin is enabled by default here so the guard group can create a
    // session; the gated group overrides this stub to disable it.
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
        isPayjoinEnabled: true,
      ),
    );
    when(() => getAvailableCurrencies.execute()).thenAnswer((_) async => []);
    when(
      () => convertSatsToCurrency.execute(
        amountSat: any(named: 'amountSat'),
        currencyCode: any(named: 'currencyCode'),
      ),
    ).thenAnswer((_) async => 1.0);
    when(
      () => getReceiveAddress.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => _testAddress());
    when(
      () => receiveWithPayjoin.execute(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
      ),
    ).thenAnswer((_) async => _receiver());
    when(() => labels.fetchByReference(any())).thenAnswer((_) async => []);
    // WatchPayjoinUsecase.execute returns a Stream<Payjoin> in the work tree.
    when(
      () => watchPayjoin.execute(ids: any(named: 'ids')),
    ).thenAnswer((_) => const Stream<Payjoin>.empty());
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
    test('does NOT broadcast the original once a proposal has been sent: '
        'the sender owns finalizing/broadcasting the payjoin tx, and a '
        'manual lower-fee rebroadcast would race/replace it', () async {
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
      ).thenAnswer((_) async => proposedPayjoin);

      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const ReceiveBitcoinStarted(null));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.payjoin, proposedPayjoin);

      bloc.add(const ReceivePayjoinOriginalTxBroadcasted());
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => broadcastOriginalTransaction.execute(any()));
      expect(bloc.state.isBroadcastingOriginalTransaction, isFalse);
    });

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
      ).thenAnswer((_) async => requestedPayjoin);
      final completedPayjoin = _receiver(
        status: PayjoinStatus.aborted,
        originalTxBytes: Uint8List.fromList([1, 2, 3]),
      );
      when(
        () => broadcastOriginalTransaction.execute(any()),
      ).thenAnswer((_) async => completedPayjoin);

      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const ReceiveBitcoinStarted(null));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.payjoin, requestedPayjoin);

      bloc.add(const ReceivePayjoinOriginalTxBroadcasted());
      await Future<void>.delayed(Duration.zero);

      verify(
        () => broadcastOriginalTransaction.execute(requestedPayjoin),
      ).called(1);
      expect(bloc.state.payjoin, completedPayjoin);
      expect(bloc.state.isBroadcastingOriginalTransaction, isFalse);
    });
  });

  group('payjoin gated on the global setting', () {
    test('does NOT create a payjoin receiver session when payjoin is '
        'disabled globally', () async {
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          isPayjoinEnabled: false,
        ),
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
      ).thenAnswer((_) async => createdPayjoin);

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
        final creation = Completer<PayjoinReceiver>();
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
        creation.complete(_receiver());
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
        ).thenAnswer((_) async => createdPayjoin);
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
    test('creates a payjoin receiver session as soon as the setting is '
        'flipped on, without needing to leave and re-enter the receive '
        'screen', () async {
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          isPayjoinEnabled: false,
        ),
      );
      final createdPayjoin = _receiver();
      when(
        () => receiveWithPayjoin.execute(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
        ),
      ).thenAnswer((_) async => createdPayjoin);

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
      ).thenAnswer((_) async => createdPayjoin);

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
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          isPayjoinEnabled: false,
        ),
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
        when(
          () => receiveWithPayjoin.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
          ),
        ).thenAnswer((_) async => first);
        final bloc = buildBloc();
        addTearDown(bloc.close);
        bloc.add(const ReceiveBitcoinStarted(null));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.payjoin?.id, 'first');

        when(
          () => receiveWithPayjoin.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
          ),
        ).thenAnswer((_) async => second);
        bloc.add(
          ReceivePayjoinUpdated(
            _receiver(id: 'first', status: PayjoinStatus.expired),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.payjoin?.id, 'second');
        expect(bloc.state.isPayjoinFlowOwningNavigation, isFalse);
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

      final label = _MockLabel();
      when(() => label.id).thenReturn(7);
      when(() => label.type).thenReturn(LabelType.address);
      when(
        () => labels.fetchByReference('bc1qtest'),
      ).thenAnswer((_) async => [label]);
      when(
        () => labels.trash(7),
      ).thenAnswer((_) async => const Ok<Null, LabelFailure>(null));

      bloc.add(const ReceiveNoteChanged(''));
      bloc.add(const ReceiveNoteSaved());
      await Future<void>.delayed(Duration.zero);

      verify(() => labels.trash(7)).called(1);
    });
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
        (_) async => [
          _testWallet(origin: 'default-btc', balanceSat: BigInt.zero),
        ],
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
      'drops repeated toggles while consent and persistence are in flight',
      () async {
        final pending = Completer<Result<bool, SettingsFailure>>();
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

        pending.complete(const Ok<bool, SettingsFailure>(true));
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
