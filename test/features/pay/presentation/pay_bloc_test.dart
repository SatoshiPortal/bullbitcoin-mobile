import 'dart:async';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/errors/pay_error.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/pay/domain/create_pay_order_usecase.dart';
import 'package:bb_mobile/features/pay/domain/get_payjoin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/refresh_pay_order_usecase.dart';
import 'package:bb_mobile/features/pay/domain/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/watch_payjoin_usecase.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Sats;

class _MockGetUserSummary extends Mock
    implements GetExchangeUserSummaryUsecase {}

class _MockPlacePayOrder extends Mock implements PlacePayOrderUsecase {}

class _MockRefreshPayOrder extends Mock implements RefreshPayOrderUsecase {}

class _MockPrepareBitcoinSend extends Mock
    implements PrepareBitcoinSendUsecase {}

class _MockPrepareLiquidSend extends Mock implements PrepareLiquidSendUsecase {}

class _MockSignBitcoinTx extends Mock implements SignBitcoinTxUsecase {}

class _MockSignLiquidTx extends Mock implements SignLiquidTxUsecase {}

class _MockBroadcastBitcoin extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

class _MockBroadcastLiquid extends Mock
    implements BroadcastLiquidTransactionUsecase {}

class _MockGetNetworkFees extends Mock implements GetNetworkFeesUsecase {}

class _MockCalculateLiquidFees extends Mock
    implements CalculateLiquidAbsoluteFeesUsecase {}

class _MockCalculateBitcoinFees extends Mock
    implements CalculateBitcoinAbsoluteFeesUsecase {}

class _MockConvertSatsToCurrency extends Mock
    implements ConvertSatsToCurrencyAmountUsecase {}

class _MockGetAddressAtIndex extends Mock implements GetAddressAtIndexUsecase {}

class _MockGetWalletUtxos extends Mock implements GetWalletUtxosUsecase {}

class _MockGetOrder extends Mock implements GetOrderUsecase {}

class _MockSendWithPayjoin extends Mock implements SendWithPayjoinUsecase {}

class _MockWatchPayjoin extends Mock implements WatchPayjoinUsecase {}

class _MockGetPayjoin extends Mock implements GetPayjoinUsecase {}

class _MockPreviewBitcoinFee extends Mock implements PreviewBitcoinFeeUsecase {}

class _MockPreviewBitcoinFeePresets extends Mock
    implements PreviewBitcoinFeePresetsUsecase {}

class _MockWallet extends Mock implements Wallet {}

class _MockPayOrder extends Mock implements FiatPaymentOrder {}

/// The confirmation path only ever runs from a [PayPaymentState] that earlier
/// events built up. Seeding it directly keeps this test to the send path and
/// avoids the order polling timer that order creation starts.
class _MockSettingsFacade extends Mock implements SettingsFacade {}

class _SeedablePayBloc extends PayBloc {
  _SeedablePayBloc({
    required super.getExchangeUserSummaryUsecase,
    required super.settingsFacade,
    required super.placePayOrderUsecase,
    required super.refreshPayOrderUsecase,
    required super.prepareBitcoinSendUsecase,
    required super.prepareLiquidSendUsecase,
    required super.signBitcoinTxUsecase,
    required super.signLiquidTxUsecase,
    required super.broadcastBitcoinTransactionUsecase,
    required super.broadcastLiquidTransactionUsecase,
    required super.sendWithPayjoinUsecase,
    required super.watchPayjoinUsecase,
    required super.getPayjoinUsecase,
    required super.getNetworkFeesUsecase,
    required super.calculateLiquidAbsoluteFeesUsecase,
    required super.calculateBitcoinAbsoluteFeesUsecase,
    required super.convertSatsToCurrencyAmountUsecase,
    required super.getAddressAtIndexUsecase,
    required super.getWalletUtxosUsecase,
    required super.getOrderUsecase,
    required super.previewBitcoinFeeUsecase,
    required super.previewBitcoinFeePresetsUsecase,
  });

  void seed(PayState state) => emit(state);
}

void main() {
  // Unsigned single-input single-output PSBT with a witness UTXO — enough for
  // the sign/broadcast mocks to have something to pass around.
  const unsignedPsbt =
      'cHNidP8BAFICAAAAARERERERERERERERERERERERERERERERERERERERERERAAAAAAD9////'
      'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
      'MzMzMzMzMzMzMzMzMzMzMzMAAA==';
  const payinAddress = 'bc1q0000000000000000000000000000000000000';
  const expectedTxid =
      '813d01e5c0ea01904322222851b2e702d37651be2644f4757cc4421f39261b55';
  const userSummary = UserSummary(
    userNumber: 1,
    groups: ['KYC_IDENTITY_VERIFIED'],
    profile: UserProfile(firstName: 'Sat', lastName: 'Oshi'),
    email: 'sat@example.com',
    balances: [],
    dca: UserDca(isActive: false),
    autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
  );
  const recipient = RecipientViewModel(
    id: 'recipient-1',
    type: RecipientType.interacEmailCad,
    email: 'payee@example.com',
  );

  // Tiers far enough apart that the rate handed to the PSBT build identifies
  // which one the bloc picked.
  final feeOptions = FeeOptions(
    fastest: NetworkFee.relativeFromSatPerVbyte(10),
    economic: NetworkFee.relativeFromSatPerVbyte(5),
    slow: NetworkFee.relativeFromSatPerVbyte(1),
    minRelay: NetworkFee.relativeFromSatPerVbyte(0.1),
  );

  late _MockPrepareBitcoinSend prepareBitcoinSend;
  late _MockSignBitcoinTx signBitcoinTx;
  late _MockConvertSatsToCurrency convertSats;
  late _MockBroadcastBitcoin broadcastBitcoin;
  late _MockCalculateBitcoinFees calculateBitcoinFees;
  late _MockGetNetworkFees getNetworkFees;
  late _MockGetOrder getOrder;
  late _MockRefreshPayOrder refreshPayOrder;
  late _MockSendWithPayjoin sendWithPayjoin;
  late _MockWatchPayjoin watchPayjoin;
  late _MockGetPayjoin getPayjoin;
  late _MockPreviewBitcoinFeePresets previewBitcoinFeePresets;
  late _MockPayOrder payOrder;
  late _MockWallet wallet;
  late _SeedablePayBloc bloc;

  /// Every `networkFee` the bloc handed to a PSBT build, in call order.
  List<NetworkFee> capturedBuildFees() => verify(
    () => prepareBitcoinSend.execute(
      walletId: any(named: 'walletId'),
      address: any(named: 'address'),
      amountSat: any(named: 'amountSat'),
      networkFee: captureAny(named: 'networkFee'),
      selectedInputs: any(named: 'selectedInputs'),
      replaceByFee: any(named: 'replaceByFee'),
    ),
  ).captured.cast<NetworkFee>();

  /// Asserts the bloc never asked for a PSBT build. Separate from
  /// [capturedBuildFees] because `verify` needs at least one matching call.
  void verifyNoBuilds() => verifyNever(
    () => prepareBitcoinSend.execute(
      walletId: any(named: 'walletId'),
      address: any(named: 'address'),
      amountSat: any(named: 'amountSat'),
      networkFee: any(named: 'networkFee'),
      selectedInputs: any(named: 'selectedInputs'),
      replaceByFee: any(named: 'replaceByFee'),
    ),
  );

  PayPaymentState paymentState({bool isConfirmingPayment = false}) =>
      PayPaymentState(
        selectedRecipient: recipient,
        userSummary: userSummary,
        amount: const FiatAmount(50),
        selectedWallet: wallet,
        payOrder: payOrder,
        absoluteFees: 200,
        isConfirmingPayment: isConfirmingPayment,
        // Present as soon as the confirmation screen is reached: the wallet
        // selection fetches the tiers to price the first estimate.
        bitcoinFees: feeOptions,
        bitcoinTxSize: 110,
      );

  setUpAll(() {
    registerFallbackValue(const NetworkFee.absolute(200));
    registerFallbackValue(<WalletUtxo>[]);
    registerFallbackValue(
      FeeOptions(
        fastest: NetworkFee.relativeFromSatPerVbyte(1),
        economic: NetworkFee.relativeFromSatPerVbyte(1),
        slow: NetworkFee.relativeFromSatPerVbyte(1),
        minRelay: NetworkFee.relativeFromSatPerVbyte(0.1),
      ),
    );
  });

  setUp(() {
    prepareBitcoinSend = _MockPrepareBitcoinSend();
    signBitcoinTx = _MockSignBitcoinTx();
    broadcastBitcoin = _MockBroadcastBitcoin();
    calculateBitcoinFees = _MockCalculateBitcoinFees();
    getNetworkFees = _MockGetNetworkFees();
    getOrder = _MockGetOrder();
    refreshPayOrder = _MockRefreshPayOrder();
    sendWithPayjoin = _MockSendWithPayjoin();
    watchPayjoin = _MockWatchPayjoin();
    convertSats = _MockConvertSatsToCurrency();
    previewBitcoinFeePresets = _MockPreviewBitcoinFeePresets();
    payOrder = _MockPayOrder();
    wallet = _MockWallet();

    when(() => wallet.id).thenReturn('wallet-1');
    when(() => wallet.isLiquid).thenReturn(false);
    when(() => wallet.network).thenReturn(Network.bitcoinMainnet);
    when(() => payOrder.orderId).thenReturn('order-1');
    when(() => payOrder.payinAmount).thenReturn(0.001);
    when(() => payOrder.payoutCurrency).thenReturn('CAD');
    when(() => payOrder.bitcoinAddress).thenReturn(payinAddress);
    // The deposit-address pinning compares orders through this getter; the
    // default order carries the creation-time address.
    when(() => payOrder.toAddress).thenReturn(payinAddress);
    // The post-broadcast completion only succeeds once the exchange sees the
    // payin; default to seen, tests that need otherwise re-stub it.
    when(() => payOrder.payinStatus).thenReturn(OrderPayinStatus.inProgress);

    when(
      () => prepareBitcoinSend.execute(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        networkFee: any(named: 'networkFee'),
        selectedInputs: any(named: 'selectedInputs'),
        replaceByFee: any(named: 'replaceByFee'),
      ),
    ).thenAnswer(
      (_) async => (unsignedPsbt: unsignedPsbt, txSize: 110, isToSelf: false),
    );
    when(
      () => calculateBitcoinFees.execute(psbt: any(named: 'psbt')),
    ).thenAnswer((_) async => 200);
    when(
      () => signBitcoinTx.execute(
        psbt: any(named: 'psbt'),
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) async => (signedPsbt: unsignedPsbt, txSize: 110));
    when(
      () => broadcastBitcoin.execute(any(), isPsbt: any(named: 'isPsbt')),
    ).thenAnswer((_) async => expectedTxid);
    when(
      () => getNetworkFees.execute(isLiquid: any(named: 'isLiquid')),
    ).thenAnswer((_) async => feeOptions);
    when(
      () => getOrder.execute(orderId: any(named: 'orderId')),
    ).thenAnswer((_) async => payOrder);
    when(
      () => watchPayjoin.execute(any()),
    ).thenAnswer((_) => const Stream.empty());
    getPayjoin = _MockGetPayjoin();
    when(() => getPayjoin.execute(any())).thenAnswer((_) async => null);

    bloc = _SeedablePayBloc(
      getExchangeUserSummaryUsecase: _MockGetUserSummary(),
      settingsFacade: _MockSettingsFacade(),
      placePayOrderUsecase: _MockPlacePayOrder(),
      refreshPayOrderUsecase: refreshPayOrder,
      prepareBitcoinSendUsecase: prepareBitcoinSend,
      prepareLiquidSendUsecase: _MockPrepareLiquidSend(),
      signBitcoinTxUsecase: signBitcoinTx,
      signLiquidTxUsecase: _MockSignLiquidTx(),
      broadcastBitcoinTransactionUsecase: broadcastBitcoin,
      broadcastLiquidTransactionUsecase: _MockBroadcastLiquid(),
      sendWithPayjoinUsecase: sendWithPayjoin,
      watchPayjoinUsecase: watchPayjoin,
      getPayjoinUsecase: getPayjoin,
      getNetworkFeesUsecase: getNetworkFees,
      calculateLiquidAbsoluteFeesUsecase: _MockCalculateLiquidFees(),
      calculateBitcoinAbsoluteFeesUsecase: calculateBitcoinFees,
      convertSatsToCurrencyAmountUsecase: convertSats,
      getAddressAtIndexUsecase: _MockGetAddressAtIndex(),
      getWalletUtxosUsecase: _MockGetWalletUtxos(),
      getOrderUsecase: getOrder,
      previewBitcoinFeeUsecase: _MockPreviewBitcoinFee(),
      previewBitcoinFeePresetsUsecase: previewBitcoinFeePresets,
    );

    bloc.seed(paymentState());
  });

  tearDown(() => bloc.close());

  group('PayBloc — broadcast latch', () {
    test(
      'does not report success while a Payjoin is only requested',
      () async {
        const bip21 =
            'bitcoin:bc1q0000000000000000000000000000000000000'
            '?amount=0.001&pj=https://payjo.in/session';
        when(() => payOrder.bip21URI).thenReturn(bip21);
        when(
          () => payOrder.confirmationDeadline,
        ).thenReturn(DateTime.now().add(const Duration(minutes: 5)));
        when(
          () => sendWithPayjoin.execute(
            walletId: any(named: 'walletId'),
            isTestnet: any(named: 'isTestnet'),
            bip21: any(named: 'bip21'),
            unsignedOriginalPsbt: any(named: 'unsignedOriginalPsbt'),
            amountSat: any(named: 'amountSat'),
            networkFeesSatPerVb: any(named: 'networkFeesSatPerVb'),
            expireAfterSec: any(named: 'expireAfterSec'),
          ),
        ).thenAnswer(
          (_) async => PayjoinSenderSession(
            status: PayjoinStatus.requested,
            uri: bip21,
            network: BitcoinNetwork.mainnet,
            walletId: 'wallet-1',
            originalTransactionId: expectedTxid,
            amount: Sats.fromInt(100000),
            createdAt: DateTime(2026),
            expiresAt: DateTime(2026).add(const Duration(minutes: 5)),
          ),
        );
        final updates = StreamController<PayjoinSession>();
        addTearDown(updates.close);
        when(
          () => watchPayjoin.execute(bip21),
        ).thenAnswer((_) => updates.stream);

        bloc.add(const PayEvent.sendPaymentConfirmed());
        await untilCalled(() => watchPayjoin.execute(bip21));
        await Future<void>.delayed(const Duration(seconds: 6));

        expect(bloc.state, isA<PayPaymentState>());
        expect((bloc.state as PayPaymentState).payinBroadcastTxid, isNull);
        expect((bloc.state as PayPaymentState).isConfirmingPayment, isTrue);

        updates.add(
          PayjoinSenderSession(
            status: PayjoinStatus.expired,
            uri: bip21,
            network: BitcoinNetwork.mainnet,
            walletId: 'wallet-1',
            originalTransactionId: expectedTxid,
            amount: Sats.fromInt(100000),
            createdAt: DateTime(2026),
            expiresAt: DateTime(2026).add(const Duration(minutes: 5)),
          ),
        );
        await pumpEventQueue();

        final expired = bloc.state as PayPaymentState;
        expect(expired.payinBroadcastTxid, isNull);
        expect(expired.isConfirmingPayment, isFalse);
        expect(expired.error, isNull);
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test('a failed Payjoin start whose session persisted is adopted, '
        'not surfaced as a retryable error', () async {
      const bip21 =
          'bitcoin:bc1q0000000000000000000000000000000000000'
          '?amount=0.001&pj=https://payjo.in/session';
      when(() => payOrder.bip21URI).thenReturn(bip21);
      when(
        () => payOrder.confirmationDeadline,
      ).thenReturn(DateTime.now().add(const Duration(minutes: 5)));
      // The engine persists the session (signed original included) before
      // posting to the directory; a post failure throws AFTER that persist.
      when(
        () => sendWithPayjoin.execute(
          walletId: any(named: 'walletId'),
          isTestnet: any(named: 'isTestnet'),
          bip21: any(named: 'bip21'),
          unsignedOriginalPsbt: any(named: 'unsignedOriginalPsbt'),
          amountSat: any(named: 'amountSat'),
          networkFeesSatPerVb: any(named: 'networkFeesSatPerVb'),
          expireAfterSec: any(named: 'expireAfterSec'),
        ),
      ).thenThrow(SendPayjoinException('Failed to start Payjoin payment'));
      when(() => getPayjoin.execute(bip21)).thenAnswer(
        (_) async => PayjoinSenderSession(
          status: PayjoinStatus.started,
          uri: bip21,
          network: BitcoinNetwork.mainnet,
          walletId: 'wallet-1',
          originalTransactionId: expectedTxid,
          amount: Sats.fromInt(100000),
          createdAt: DateTime(2026),
          expiresAt: DateTime(2026).add(const Duration(minutes: 5)),
        ),
      );

      bloc.add(const PayEvent.sendPaymentConfirmed());
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // The persisted session WILL broadcast its original at the deadline.
      // Re-arming Confirm here would let a plain retry pay the same order
      // again on disjoint inputs (the session's inputs are reserved), so
      // the payment must stay latched on the adopted session instead.
      final state = bloc.state as PayPaymentState;
      expect(state.error, isNull);
      expect(
        state.isConfirmingPayment,
        isTrue,
        reason:
            'an adopted session keeps Confirm latched until the session '
            'resolves — re-arming it opens the double-payment window',
      );
      verify(() => watchPayjoin.execute(bip21)).called(1);
      verifyNever(
        () => broadcastBitcoin.execute(any(), isPsbt: any(named: 'isPsbt')),
      );
    });

    test('a failed Payjoin start with nothing persisted still surfaces the '
        'retryable error', () async {
      const bip21 =
          'bitcoin:bc1q0000000000000000000000000000000000000'
          '?amount=0.001&pj=https://payjo.in/session';
      when(() => payOrder.bip21URI).thenReturn(bip21);
      when(
        () => payOrder.confirmationDeadline,
      ).thenReturn(DateTime.now().add(const Duration(minutes: 5)));
      when(
        () => sendWithPayjoin.execute(
          walletId: any(named: 'walletId'),
          isTestnet: any(named: 'isTestnet'),
          bip21: any(named: 'bip21'),
          unsignedOriginalPsbt: any(named: 'unsignedOriginalPsbt'),
          amountSat: any(named: 'amountSat'),
          networkFeesSatPerVb: any(named: 'networkFeesSatPerVb'),
          expireAfterSec: any(named: 'expireAfterSec'),
        ),
      ).thenThrow(SendPayjoinException('Failed to start Payjoin payment'));
      // No session row: the failure happened before the write-ahead
      // persist, so nothing can broadcast later and retrying is safe.
      when(() => getPayjoin.execute(bip21)).thenAnswer((_) async => null);

      bloc.add(const PayEvent.sendPaymentConfirmed());
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = bloc.state as PayPaymentState;
      expect(state.error, isNotNull);
      expect(state.isConfirmingPayment, isFalse);
      verifyNever(() => watchPayjoin.execute(any()));
    });

    test('a second confirmation cannot start a second Payjoin', () async {
      const bip21 =
          'bitcoin:bc1q0000000000000000000000000000000000000'
          '?amount=0.001&pj=https://payjo.in/session';
      when(() => payOrder.bip21URI).thenReturn(bip21);
      when(
        () => payOrder.confirmationDeadline,
      ).thenReturn(DateTime.now().add(const Duration(minutes: 5)));
      when(
        () => sendWithPayjoin.execute(
          walletId: any(named: 'walletId'),
          isTestnet: any(named: 'isTestnet'),
          bip21: any(named: 'bip21'),
          unsignedOriginalPsbt: any(named: 'unsignedOriginalPsbt'),
          amountSat: any(named: 'amountSat'),
          networkFeesSatPerVb: any(named: 'networkFeesSatPerVb'),
          expireAfterSec: any(named: 'expireAfterSec'),
        ),
      ).thenAnswer(
        (_) async => PayjoinSenderSession(
          status: PayjoinStatus.requested,
          uri: bip21,
          network: BitcoinNetwork.mainnet,
          walletId: 'wallet-1',
          originalTransactionId: expectedTxid,
          amount: Sats.fromInt(100000),
          createdAt: DateTime(2026),
          expiresAt: DateTime(2026).add(const Duration(minutes: 5)),
        ),
      );
      final updates = StreamController<PayjoinSession>();
      addTearDown(updates.close);
      when(() => watchPayjoin.execute(bip21)).thenAnswer((_) => updates.stream);

      bloc.add(const PayEvent.sendPaymentConfirmed());
      await untilCalled(() => watchPayjoin.execute(bip21));

      // The original transaction is already committed to the receiver, so a
      // second confirmation must not build and hand over another one.
      bloc.add(const PayEvent.sendPaymentConfirmed());
      await Future<void>.delayed(const Duration(milliseconds: 100));

      verify(
        () => sendWithPayjoin.execute(
          walletId: any(named: 'walletId'),
          isTestnet: any(named: 'isTestnet'),
          bip21: any(named: 'bip21'),
          unsignedOriginalPsbt: any(named: 'unsignedOriginalPsbt'),
          amountSat: any(named: 'amountSat'),
          networkFeesSatPerVb: any(named: 'networkFeesSatPerVb'),
          expireAfterSec: any(named: 'expireAfterSec'),
        ),
      ).called(1);
      verify(
        () => prepareBitcoinSend.execute(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
          amountSat: any(named: 'amountSat'),
          networkFee: any(named: 'networkFee'),
          selectedInputs: any(named: 'selectedInputs'),
          replaceByFee: any(named: 'replaceByFee'),
        ),
      ).called(1);
    });

    test(
      'a post-broadcast failure never allows a second broadcast',
      () async {
        when(
          () => getOrder.execute(orderId: any(named: 'orderId')),
        ).thenThrow(GetOrderException('backend unavailable'));

        bloc.add(const PayEvent.sendPaymentConfirmed());
        await bloc.stream.firstWhere(
          (state) => state is PayPaymentState && state.isPayinBroadcast,
        );
        await Future<void>.delayed(const Duration(seconds: 6));

        final latched = bloc.state as PayPaymentState;
        expect(latched.payinBroadcastTxid, expectedTxid);
        expect(latched.isConfirmingPayment, isTrue);
        expect(latched.error, isNull);

        bloc.add(const PayEvent.sendPaymentConfirmed());
        await Future<void>.delayed(const Duration(milliseconds: 100));

        verify(
          () => broadcastBitcoin.execute(any(), isPsbt: any(named: 'isPsbt')),
        ).called(1);
        verify(
          () => prepareBitcoinSend.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
            amountSat: any(named: 'amountSat'),
            networkFee: any(named: 'networkFee'),
            selectedInputs: any(named: 'selectedInputs'),
            replaceByFee: any(named: 'replaceByFee'),
          ),
        ).called(1);
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    test('simultaneous confirmations start one send only', () async {
      final build =
          Completer<({String unsignedPsbt, int txSize, bool isToSelf})>();
      when(
        () => prepareBitcoinSend.execute(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
          amountSat: any(named: 'amountSat'),
          networkFee: any(named: 'networkFee'),
          selectedInputs: any(named: 'selectedInputs'),
          replaceByFee: any(named: 'replaceByFee'),
        ),
      ).thenAnswer((_) => build.future);

      bloc.add(const PayEvent.sendPaymentConfirmed());
      bloc.add(const PayEvent.sendPaymentConfirmed());
      await Future<void>.delayed(const Duration(milliseconds: 100));

      verify(
        () => prepareBitcoinSend.execute(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
          amountSat: any(named: 'amountSat'),
          networkFee: any(named: 'networkFee'),
          selectedInputs: any(named: 'selectedInputs'),
          replaceByFee: any(named: 'replaceByFee'),
        ),
      ).called(1);

      build.complete((
        unsignedPsbt: unsignedPsbt,
        txSize: 110,
        isToSelf: false,
      ));
      await bloc.stream.firstWhere(
        (state) => state is PayPaymentState && state.isPayinBroadcast,
      );
    });

    test('a price refresh cannot overwrite a confirmation in flight', () async {
      final refresh = Completer<FiatPaymentOrder>();
      when(
        () => refreshPayOrder.execute(
          orderId: any(named: 'orderId'),
          expectedDepositAddress: any(named: 'expectedDepositAddress'),
        ),
      ).thenAnswer((_) => refresh.future);

      bloc.add(const PayEvent.orderRefreshTimePassed());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      bloc.seed(paymentState(isConfirmingPayment: true));
      refresh.complete(payOrder);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect((bloc.state as PayPaymentState).isConfirmingPayment, isTrue);
    });

    test('Payjoin toggle is ignored while confirmation is in flight', () async {
      bloc.seed(paymentState(isConfirmingPayment: true));

      bloc.add(const PayEvent.payjoinToggled(false));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect((bloc.state as PayPaymentState).isPayjoinEnabled, isTrue);
    });

    test('an order poll spanning broadcast preserves the latch', () async {
      final poll = Completer<Order>();
      when(
        () => getOrder.execute(orderId: any(named: 'orderId')),
      ).thenAnswer((_) => poll.future);
      when(
        () => payOrder.payinStatus,
      ).thenReturn(OrderPayinStatus.awaitingPayment);

      bloc.add(const PayEvent.pollOrderStatus());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      bloc.seed(
        paymentState(
          isConfirmingPayment: true,
        ).copyWith(payinBroadcastTxid: expectedTxid),
      );
      poll.complete(payOrder);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = bloc.state as PayPaymentState;
      expect(state.payinBroadcastTxid, expectedTxid);
      expect(state.isConfirmingPayment, isTrue);
    });

    test('absolute custom fees pass their actual rate to Payjoin', () async {
      const bip21 =
          'bitcoin:bc1q0000000000000000000000000000000000000'
          '?amount=0.001&pj=https://payjo.in/session';
      when(() => payOrder.bip21URI).thenReturn(bip21);
      when(
        () => payOrder.confirmationDeadline,
      ).thenReturn(DateTime.now().add(const Duration(minutes: 5)));
      when(
        () => calculateBitcoinFees.execute(psbt: any(named: 'psbt')),
      ).thenAnswer((_) async => 1100);
      when(
        () => sendWithPayjoin.execute(
          walletId: any(named: 'walletId'),
          isTestnet: any(named: 'isTestnet'),
          bip21: any(named: 'bip21'),
          unsignedOriginalPsbt: any(named: 'unsignedOriginalPsbt'),
          amountSat: any(named: 'amountSat'),
          networkFeesSatPerVb: any(named: 'networkFeesSatPerVb'),
          expireAfterSec: any(named: 'expireAfterSec'),
        ),
      ).thenAnswer(
        (_) async => PayjoinSenderSession(
          status: PayjoinStatus.requested,
          uri: bip21,
          network: BitcoinNetwork.mainnet,
          walletId: 'wallet-1',
          originalTransactionId: expectedTxid,
          amount: Sats.fromInt(100000),
          createdAt: DateTime(2026),
          expiresAt: DateTime(2026).add(const Duration(minutes: 5)),
        ),
      );
      when(() => watchPayjoin.execute(bip21)).thenAnswer(
        (_) => Stream.value(
          PayjoinSenderSession(
            status: PayjoinStatus.completed,
            uri: bip21,
            network: BitcoinNetwork.mainnet,
            walletId: 'wallet-1',
            originalTransactionId: 'original-txid',
            transactionId: expectedTxid,
            amount: Sats.fromInt(100000),
            createdAt: DateTime(2026),
            expiresAt: DateTime(2026).add(const Duration(minutes: 5)),
          ),
        ),
      );
      bloc.seed(
        paymentState().copyWith(
          selectedFeeOption: FeeSelection.custom,
          customFee: const NetworkFee.absolute(1100),
          absoluteFees: 1100,
        ),
      );

      bloc.add(const PayEvent.sendPaymentConfirmed());
      await bloc.stream.firstWhere(
        (state) => state is PayPaymentState && state.isPayinBroadcast,
      );

      verify(
        () => sendWithPayjoin.execute(
          walletId: 'wallet-1',
          isTestnet: false,
          bip21: bip21,
          unsignedOriginalPsbt: unsignedPsbt,
          amountSat: 100000,
          networkFeesSatPerVb: 10,
          expireAfterSec: any(named: 'expireAfterSec'),
        ),
      ).called(1);
    });
  });

  group('PayBloc — fee selection (#2521)', () {
    /// Resolves once the fee recalculation triggered by a selection has landed.
    Future<PayPaymentState> awaitRecalculatedFee() async {
      final state = await bloc.stream.firstWhere(
        (state) => state is PayPaymentState && state.absoluteFees != null,
      );
      return state as PayPaymentState;
    }

    /// Parks a fee recalculation inside its network-fee fetch, then moves the
    /// flow to the success state underneath it. Returns the completer so the
    /// caller decides whether the parked fetch succeeds or fails.
    Future<Completer<FeeOptions>> recalculationParkedPastSuccess() async {
      final feeFetch = Completer<FeeOptions>();
      when(
        () => getNetworkFees.execute(isLiquid: any(named: 'isLiquid')),
      ).thenAnswer((_) => feeFetch.future);

      bloc.add(const PayEvent.feeOptionSelected(FeeSelection.slow));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Stands in for the payin being broadcast and the order catching up while
      // the recalculation is still waiting on mempool rates.
      bloc.seed(PayState.success(payOrder: payOrder));
      return feeFetch;
    }

    test('a recalculation landing after the success transition emits '
        'nothing', () async {
      final feeFetch = await recalculationParkedPastSuccess();

      feeFetch.complete(feeOptions);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Republishing the pre-broadcast payment state here would take the user
      // off the success screen and re-arm Confirm on a payin already on the
      // wire. Pay has no broadcast latch, so nothing else would stop a second
      // payment.
      expect(bloc.state, isA<PaySuccessState>());
    });

    test('a recalculation failing after the success transition emits '
        'nothing', () async {
      final feeFetch = await recalculationParkedPastSuccess();

      feeFetch.completeError(Exception('mempool unreachable'));
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Same for the failure path: an error emitted onto a resurrected payment
      // state is an invitation to pay twice.
      expect(bloc.state, isA<PaySuccessState>());
    });

    /// Prices the three preset tiles the way an opened modal does.
    void stubPresetPreviews() {
      when(
        () => previewBitcoinFeePresets.execute(
          presets: any(named: 'presets'),
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
          amountSat: any(named: 'amountSat'),
          replaceByFee: any(named: 'replaceByFee'),
          selectedInputs: any(named: 'selectedInputs'),
          drain: any(named: 'drain'),
        ),
      ).thenAnswer(
        (_) async => const {
          FeeSelection.fastest: BitcoinFeePreviewSlot(
            feeSat: 1100,
            unsignedPsbt: unsignedPsbt,
            txSize: 110,
          ),
          FeeSelection.economic: BitcoinFeePreviewSlot(
            feeSat: 550,
            unsignedPsbt: unsignedPsbt,
            txSize: 110,
          ),
          FeeSelection.slow: BitcoinFeePreviewSlot(
            feeSat: 110,
            unsignedPsbt: unsignedPsbt,
            txSize: 110,
          ),
        },
      );
    }

    /// Resolves once the preset previews have filled the cache.
    Future<PayPaymentState> awaitPricedPresets() async {
      final state = await bloc.stream.firstWhere(
        (state) =>
            state is PayPaymentState &&
            !state.feePreviewCache.presetsLoading &&
            state.feePreviewCache.fastest.feeSat != null,
      );
      return state as PayPaymentState;
    }

    test('typing a custom rate leaves the preset prices standing', () async {
      stubPresetPreviews();
      bloc.add(const PayEvent.presetFeesPreviewRequested());
      await awaitPricedPresets();

      bloc.add(PayEvent.customFeeArmed(NetworkFee.relativeFromSatPerVbyte(4)));
      await bloc.stream.firstWhere(
        (state) =>
            state is PayPaymentState &&
            state.selectedFeeOption == FeeSelection.custom,
      );

      final cache = (bloc.state as PayPaymentState).feePreviewCache;
      // Only the custom slot priced the rate that just changed; wiping the
      // presets too would blank their tiles until the modal is reopened.
      expect(cache.fastest.feeSat, 1100);
      expect(cache.economic.feeSat, 550);
      expect(cache.slow.feeSat, 110);
      expect(cache.custom.feeSat, isNull);
    });

    test(
      'the payin is built at the selected preset, not Fastest',
      () async {
        bloc.add(const PayEvent.feeOptionSelected(FeeSelection.slow));
        final recalculated = await awaitRecalculatedFee();
        expect(recalculated.selectedFeeOption, FeeSelection.slow);

        bloc.add(const PayEvent.sendPaymentConfirmed());
        await bloc.stream.firstWhere((state) => state is PaySuccessState);

        // Both the estimate rebuild and the broadcast build used Slow; the
        // hardcoded Fastest rate must appear nowhere.
        expect(capturedBuildFees(), everyElement(equals(feeOptions.slow)));
        verify(
          () => broadcastBitcoin.execute(any(), isPsbt: any(named: 'isPsbt')),
        ).called(1);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'a typed custom rate is committed on dismissal and paid',
      () async {
        final customFee = NetworkFee.relativeFromSatPerVbyte(3);

        // Typing arms the rate without rebuilding; dismissing the modal is what
        // applies it.
        bloc.add(PayEvent.customFeeArmed(customFee));
        await bloc.stream.firstWhere(
          (state) =>
              state is PayPaymentState &&
              state.selectedFeeOption == FeeSelection.custom,
        );
        verifyNoBuilds();

        bloc.add(const PayEvent.customFeeFinalized());
        final committed = await awaitRecalculatedFee();
        expect(committed.customFee, customFee);
        expect(committed.armPriorSelection, isNull);

        bloc.add(const PayEvent.sendPaymentConfirmed());
        await bloc.stream.firstWhere((state) => state is PaySuccessState);

        expect(capturedBuildFees(), everyElement(equals(customFee)));
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'a custom rate below the relay floor rolls back on dismissal',
      () async {
        // 0.05 sat/vB is under the 0.1 sat/vB floor, so dismissing discards it
        // rather than staging a transaction the network would not relay.
        bloc.add(
          PayEvent.customFeeArmed(NetworkFee.relativeFromSatPerVbyte(0.05)),
        );
        await bloc.stream.firstWhere(
          (state) =>
              state is PayPaymentState &&
              state.selectedFeeOption == FeeSelection.custom,
        );

        bloc.add(const PayEvent.customFeeFinalized());
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final state = bloc.state as PayPaymentState;
        expect(state.selectedFeeOption, FeeSelection.fastest);
        expect(state.customFee, isNull);
        verifyNoBuilds();
      },
    );

    test(
      'fee selection is inert while the confirmation is in flight',
      () async {
        bloc.seed(paymentState(isConfirmingPayment: true));

        // Changing the fee now would rebuild the transaction being signed.
        bloc.add(const PayEvent.feeOptionSelected(FeeSelection.slow));
        bloc.add(
          PayEvent.customFeeArmed(NetworkFee.relativeFromSatPerVbyte(9)),
        );
        bloc.add(const PayEvent.presetFeesPreviewRequested());
        await Future<void>.delayed(const Duration(milliseconds: 200));

        final state = bloc.state as PayPaymentState;
        expect(state.selectedFeeOption, FeeSelection.fastest);
        expect(state.customFee, isNull);
        verifyNoBuilds();
        verifyNever(
          () => previewBitcoinFeePresets.execute(
            presets: any(named: 'presets'),
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
            amountSat: any(named: 'amountSat'),
            replaceByFee: any(named: 'replaceByFee'),
            selectedInputs: any(named: 'selectedInputs'),
            drain: any(named: 'drain'),
          ),
        );
      },
    );

    test('opening the modal prices each preset from a built PSBT', () async {
      stubPresetPreviews();

      bloc.add(const PayEvent.presetFeesPreviewRequested());
      final state = await awaitPricedPresets();

      expect(state.feePreviewCache.fastest.feeSat, 1100);
      expect(state.feePreviewCache.economic.feeSat, 550);
      expect(state.feePreviewCache.slow.feeSat, 110);
      // The previews price the real payin, not a stand-in address.
      verify(
        () => previewBitcoinFeePresets.execute(
          presets: feeOptions,
          walletId: 'wallet-1',
          address: payinAddress,
          amountSat: 100000,
          replaceByFee: any(named: 'replaceByFee'),
          selectedInputs: any(named: 'selectedInputs'),
          drain: false,
        ),
      ).called(1);
    });
  });

  group('PayBloc — audit reproducers (H6, H7)', () {
    test('a wallet selection during confirmation is ignored (H6)', () async {
      bloc.seed(paymentState(isConfirmingPayment: true));
      when(
        () => convertSats.execute(currencyCode: any(named: 'currencyCode')),
      ).thenAnswer((_) async => 100000.0);

      bloc.add(PayEvent.walletSelected(wallet: wallet));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        bloc.state,
        isA<PayPaymentState>(),
        reason:
            'tearing down the payment state mid-confirmation orphans the '
            'in-flight payment and lets a later payjoin resolution latch '
            'onto a different order',
      );
      expect((bloc.state as PayPaymentState).isConfirmingPayment, isTrue);
    });

    test(
      'a rate-conversion failure surfaces an error, not a stuck spinner (H7)',
      () async {
        bloc.seed(
          PayState.walletSelection(
            selectedRecipient: recipient,
            userSummary: userSummary,
            amount: const FiatAmount(50),
          ),
        );
        when(
          () => convertSats.execute(currencyCode: any(named: 'currencyCode')),
        ).thenThrow(StateError('price API unavailable'));

        final states = <PayState>[];
        final subscription = bloc.stream.listen(states.add);
        bloc.add(PayEvent.walletSelected(wallet: wallet));
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await subscription.cancel();

        final last = bloc.state;
        expect(
          last,
          isA<PayWalletSelectionState>(),
          reason: 'the handler must recover to the wallet-selection state',
        );
        final selection = last as PayWalletSelectionState;
        expect(
          selection.error,
          isNotNull,
          reason:
              'awaited outside any try, a price-API failure escapes the '
              'handler: no error state, and the order-creation spinner '
              'stays latched with no retry path',
        );
        expect(selection.isCreatingPayOrder, isFalse);
      },
    );
  });

  group('PayBloc — deposit address pinning', () {
    /// A refresh response whose deposit address differs from the one the
    /// order was created with. Stands in for a compromised backend or a
    /// MITM rewriting the exchange API response.
    _MockPayOrder tamperedOrder() {
      final order = _MockPayOrder();
      when(() => order.orderId).thenReturn('order-1');
      when(() => order.payinAmount).thenReturn(0.001);
      when(() => order.payoutCurrency).thenReturn('CAD');
      when(
        () => order.toAddress,
      ).thenReturn('bc1qattacker00000000000000000000000000000');
      return order;
    }

    test('audit reproducer: a refreshed order carrying a different deposit '
        'address is refused, never adopted', () async {
      // Before the fix, _onOrderRefreshTimePassed replaced the whole order
      // unconditionally and the confirm screen never showed the address, so
      // a tampered refresh silently redirected the payin.
      when(
        () => refreshPayOrder.execute(
          orderId: any(named: 'orderId'),
          expectedDepositAddress: any(named: 'expectedDepositAddress'),
        ),
      ).thenThrow(const PayError.depositAddressChanged());

      bloc.add(const PayEvent.orderRefreshTimePassed());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = bloc.state as PayPaymentState;
      expect(
        state.payOrder,
        same(payOrder),
        reason:
            'a refreshed order with a different deposit address must never '
            'replace the order the payin is built from',
      );
      expect(state.error, isA<DepositAddressChangedPayError>());
    });

    test(
      'a refreshed order carrying the same deposit address is adopted',
      () async {
        final refreshedOrder = _MockPayOrder();
        when(() => refreshedOrder.orderId).thenReturn('order-1');
        // A new price lock moves the payin amount — that part of the refresh
        // must keep working.
        when(() => refreshedOrder.payinAmount).thenReturn(0.002);
        when(() => refreshedOrder.payoutCurrency).thenReturn('CAD');
        when(() => refreshedOrder.toAddress).thenReturn(payinAddress);
        when(
          () => refreshPayOrder.execute(
            orderId: any(named: 'orderId'),
            expectedDepositAddress: any(named: 'expectedDepositAddress'),
          ),
        ).thenAnswer((_) async => refreshedOrder);

        bloc.add(const PayEvent.orderRefreshTimePassed());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final state = bloc.state as PayPaymentState;
        expect(state.payOrder, same(refreshedOrder));
        expect(state.error, isNull);
      },
    );

    test('a polled order carrying a different deposit address is refused '
        'while the payment is still unsigned', () async {
      // The periodic order poll is a second adoption path for a tampered
      // order: it merges the fetched order into the live payment state.
      final tampered = tamperedOrder();
      when(
        () => tampered.payinStatus,
      ).thenReturn(OrderPayinStatus.awaitingPayment);
      when(
        () => getOrder.execute(orderId: any(named: 'orderId')),
      ).thenAnswer((_) async => tampered);

      bloc.add(const PayEvent.pollOrderStatus());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = bloc.state as PayPaymentState;
      expect(state.payOrder, same(payOrder));
      expect(state.error, isA<DepositAddressChangedPayError>());
    });

    test(
      'a changed address is refused even when the poll reports progress',
      () async {
        final tampered = tamperedOrder();
        when(
          () => tampered.payinStatus,
        ).thenReturn(OrderPayinStatus.inProgress);
        when(
          () => getOrder.execute(orderId: any(named: 'orderId')),
        ).thenAnswer((_) async => tampered);

        bloc.add(const PayEvent.pollOrderStatus());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(bloc.state, isA<PayPaymentState>());
        expect(
          (bloc.state as PayPaymentState).error,
          isA<DepositAddressChangedPayError>(),
        );
      },
    );

    test('after a refused refresh, the payin still targets the creation-time '
        'address', () async {
      when(
        () => refreshPayOrder.execute(
          orderId: any(named: 'orderId'),
          expectedDepositAddress: any(named: 'expectedDepositAddress'),
        ),
      ).thenThrow(const PayError.depositAddressChanged());

      bloc.add(const PayEvent.orderRefreshTimePassed());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        (bloc.state as PayPaymentState).error,
        isA<DepositAddressChangedPayError>(),
      );

      bloc.add(const PayEvent.sendPaymentConfirmed());
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final builtAddresses = verify(
        () => prepareBitcoinSend.execute(
          walletId: any(named: 'walletId'),
          address: captureAny(named: 'address'),
          amountSat: any(named: 'amountSat'),
          networkFee: any(named: 'networkFee'),
          selectedInputs: any(named: 'selectedInputs'),
          replaceByFee: any(named: 'replaceByFee'),
        ),
      ).captured;
      expect(
        builtAddresses,
        everyElement(payinAddress),
        reason:
            'the payin must only ever pay the address the order was created '
            'with',
      );

      // Let the confirmation settle so nothing emits after tearDown closes.
      await Future<void>.delayed(const Duration(seconds: 6));
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
