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
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_address_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/receive/domain/usecases/create_receive_swap_use_case.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
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

class _MockGetSwapLimitsUsecase extends Mock implements GetSwapLimitsUsecase {}

Wallet _testWallet({String origin = 'w1'}) => Wallet(
  origin: origin,
  network: Network.bitcoinMainnet,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
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
  late _MockGetSettingsUsecase getSettings;
  late _MockGetAvailableCurrenciesUsecase getAvailableCurrencies;
  late _MockConvertSatsToCurrencyAmountUsecase convertSatsToCurrency;
  late _MockGetReceiveAddressUsecase getReceiveAddress;
  late _MockReceiveWithPayjoinUsecase receiveWithPayjoin;
  late _MockBroadcastOriginalTransactionUsecase broadcastOriginalTransaction;
  late _MockWatchPayjoinUsecase watchPayjoin;
  late _MockWatchWalletTransactionByAddressUsecase watchWalletTransaction;
  late _MockLabelsFacade labels;

  setUpAll(() {
    registerFallbackValue(_receiver());
  });

  ReceiveBloc buildBloc() => ReceiveBloc(
    getWalletsUsecase: _MockGetWalletsUsecase(),
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
    wallet: _testWallet(),
  );

  setUp(() {
    getSettings = _MockGetSettingsUsecase();
    getAvailableCurrencies = _MockGetAvailableCurrenciesUsecase();
    convertSatsToCurrency = _MockConvertSatsToCurrencyAmountUsecase();
    getReceiveAddress = _MockGetReceiveAddressUsecase();
    receiveWithPayjoin = _MockReceiveWithPayjoinUsecase();
    broadcastOriginalTransaction = _MockBroadcastOriginalTransactionUsecase();
    watchPayjoin = _MockWatchPayjoinUsecase();
    watchWalletTransaction = _MockWatchWalletTransactionByAddressUsecase();
    labels = _MockLabelsFacade();

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
  });
}
