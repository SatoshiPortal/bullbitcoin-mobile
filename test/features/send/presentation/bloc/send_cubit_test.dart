import 'dart:async';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/create_chain_swap_to_external_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/decode_invoice_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/update_send_swap_lockup_fees_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_pset_size_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/select_best_wallet_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/update_paid_send_swap_usecase.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLabelsFacade extends Mock implements LabelsFacade {}

class _MockSelectBestWalletUsecase extends Mock
    implements SelectBestWalletUsecase {}

class _MockDetectBitcoinStringUsecase extends Mock
    implements DetectBitcoinStringUsecase {}

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockConvertSatsToCurrencyAmountUsecase extends Mock
    implements ConvertSatsToCurrencyAmountUsecase {}

class _MockGetNetworkFeesUsecase extends Mock
    implements GetNetworkFeesUsecase {}

class _MockGetWalletUtxosUsecase extends Mock
    implements GetWalletUtxosUsecase {}

class _MockGetAvailableCurrenciesUsecase extends Mock
    implements GetAvailableCurrenciesUsecase {}

class _MockPrepareBitcoinSendUsecase extends Mock
    implements PrepareBitcoinSendUsecase {}

class _MockPrepareLiquidSendUsecase extends Mock
    implements PrepareLiquidSendUsecase {}

class _MockSendWithPayjoinUsecase extends Mock
    implements SendWithPayjoinUsecase {}

class _MockWatchPayjoinUsecase extends Mock implements WatchPayjoinUsecase {}

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class _MockCreateSendSwapUsecase extends Mock
    implements CreateSendSwapUsecase {}

class _MockUpdatePaidSendSwapUsecase extends Mock
    implements UpdatePaidSendSwapUsecase {}

class _MockGetSwapLimitsUsecase extends Mock implements GetSwapLimitsUsecase {}

class _MockWatchSwapUsecase extends Mock implements WatchSwapUsecase {}

class _MockWatchFinishedWalletSyncsUsecase extends Mock
    implements WatchFinishedWalletSyncsUsecase {}

class _MockDecodeInvoiceUsecase extends Mock implements DecodeInvoiceUsecase {}

class _MockSignBitcoinTxUsecase extends Mock implements SignBitcoinTxUsecase {}

class _MockSignLiquidTxUsecase extends Mock implements SignLiquidTxUsecase {}

class _MockBroadcastBitcoinTransactionUsecase extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

class _MockBroadcastLiquidTransactionUsecase extends Mock
    implements BroadcastLiquidTransactionUsecase {}

class _MockCalculateLiquidAbsoluteFeesUsecase extends Mock
    implements CalculateLiquidAbsoluteFeesUsecase {}

class _MockCalculateLiquidPsetSizeUsecase extends Mock
    implements CalculateLiquidPsetSizeUsecase {}

class _MockCreateChainSwapToExternalUsecase extends Mock
    implements CreateChainSwapToExternalUsecase {}

class _MockWatchWalletTransactionByTxIdUsecase extends Mock
    implements WatchWalletTransactionByTxIdUsecase {}

class _MockCalculateBitcoinAbsoluteFeesUsecase extends Mock
    implements CalculateBitcoinAbsoluteFeesUsecase {}

class _MockUpdateSendSwapLockupFeesUsecase extends Mock
    implements UpdateSendSwapLockupFeesUsecase {}

class _MockVerifyChainSwapAmountSendUsecase extends Mock
    implements VerifyChainSwapAmountSendUsecase {}

class _MockPreviewBitcoinFeeUsecase extends Mock
    implements PreviewBitcoinFeeUsecase {}

class _MockPreviewBitcoinFeePresetsUsecase extends Mock
    implements PreviewBitcoinFeePresetsUsecase {}

class _MockCheckLiquidConsolidationUsecase extends Mock
    implements CheckLiquidConsolidationUsecase {}

class _FakeNewLabel extends Fake implements NewLabel {}

/// Test seam: [SendCubit]'s payjoin watcher ([_watchPayjoin]) is private and
/// only started from the tail of the public [SendCubit.signTransaction]. This
/// subclass exposes [emit] so a test can stage exactly the precondition state
/// that drives `signTransaction` into its payjoin branch — nothing about the
/// production class is changed; the tests exercise the real
/// `signTransaction` → `_watchPayjoin` code path.
class _TestableSendCubit extends SendCubit {
  _TestableSendCubit({
    required super.labelsFacade,
    required super.bestWalletUsecase,
    required super.detectBitcoinStringUsecase,
    required super.getSettingsUsecase,
    required super.convertSatsToCurrencyAmountUsecase,
    required super.getNetworkFeesUsecase,
    required super.getWalletUtxosUsecase,
    required super.getAvailableCurrenciesUsecase,
    required super.prepareBitcoinSendUsecase,
    required super.prepareLiquidSendUsecase,
    required super.sendWithPayjoinUsecase,
    required super.watchPayjoinUsecase,
    required super.getWalletsUsecase,
    required super.getWalletUsecase,
    required super.createSendSwapUsecase,
    required super.updatePaidSendSwapUsecase,
    required super.getSwapLimitsUsecase,
    required super.watchSwapUsecase,
    required super.watchFinishedWalletSyncsUsecase,
    required super.decodeInvoiceUsecase,
    required super.signBitcoinTxUsecase,
    required super.signLiquidTxUsecase,
    required super.broadcastBitcoinTxUsecase,
    required super.broadcastLiquidTxUsecase,
    required super.calculateLiquidAbsoluteFeesUsecase,
    required super.calculateLiquidPsetSizeUsecase,
    required super.createChainSwapToExternalUsecase,
    required super.watchWalletTransactionByTxIdUsecase,
    required super.calculateBitcoinAbsoluteFeesUsecase,
    required super.updateSendSwapLockupFeesUsecase,
    required super.verifyChainSwapAmountSendUsecase,
    required super.previewBitcoinFeeUsecase,
    required super.previewBitcoinFeePresetsUsecase,
    required super.checkLiquidConsolidationUsecase,
  });

  void setStateForTest(SendState state) => emit(state);
}

Wallet _bitcoinLocalWallet() => Wallet(
  origin: 'w1',
  network: Network.bitcoinMainnet,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(1000000),
);

Bip21PaymentRequest _payjoinBip21() =>
    const PaymentRequest.bip21(
          network: Network.bitcoinMainnet,
          uri: 'bitcoin:bc1qaddr?amount=0.0005&pj=https://payjo.in',
          address: 'bc1qaddr',
          amountSat: 50000,
          pj: 'https://payjo.in',
        )
        as Bip21PaymentRequest;

PayjoinSender _sender({
  required PayjoinStatus status,
  String? txId,
  String originalTxId = 'sender-orig-txid',
}) =>
    Payjoin.sender(
          status: status,
          uri: 'bitcoin:bc1qaddr?amount=0.0005&pj=https://payjo.in',
          isTestnet: false,
          walletId: 'w1',
          originalPsbt: 'cHNidP8=',
          originalTxId: originalTxId,
          amountSat: 50000,
          createdAt: DateTime(2026),
          expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
          txId: txId,
        )
        as PayjoinSender;

void main() {
  late _MockLabelsFacade labelsFacade;
  late _MockSelectBestWalletUsecase bestWalletUsecase;
  late _MockDetectBitcoinStringUsecase detectBitcoinStringUsecase;
  late _MockGetSettingsUsecase getSettingsUsecase;
  late _MockConvertSatsToCurrencyAmountUsecase convertSatsUsecase;
  late _MockGetNetworkFeesUsecase getNetworkFeesUsecase;
  late _MockGetWalletUtxosUsecase getWalletUtxosUsecase;
  late _MockGetAvailableCurrenciesUsecase getAvailableCurrenciesUsecase;
  late _MockPrepareBitcoinSendUsecase prepareBitcoinSendUsecase;
  late _MockPrepareLiquidSendUsecase prepareLiquidSendUsecase;
  late _MockSendWithPayjoinUsecase sendWithPayjoinUsecase;
  late _MockWatchPayjoinUsecase watchPayjoinUsecase;
  late _MockGetWalletsUsecase getWalletsUsecase;
  late _MockGetWalletUsecase getWalletUsecase;
  late _MockCreateSendSwapUsecase createSendSwapUsecase;
  late _MockUpdatePaidSendSwapUsecase updatePaidSendSwapUsecase;
  late _MockGetSwapLimitsUsecase getSwapLimitsUsecase;
  late _MockWatchSwapUsecase watchSwapUsecase;
  late _MockWatchFinishedWalletSyncsUsecase watchFinishedWalletSyncsUsecase;
  late _MockDecodeInvoiceUsecase decodeInvoiceUsecase;
  late _MockSignBitcoinTxUsecase signBitcoinTxUsecase;
  late _MockSignLiquidTxUsecase signLiquidTxUsecase;
  late _MockBroadcastBitcoinTransactionUsecase broadcastBitcoinTxUsecase;
  late _MockBroadcastLiquidTransactionUsecase broadcastLiquidTxUsecase;
  late _MockCalculateLiquidAbsoluteFeesUsecase
  calculateLiquidAbsoluteFeesUsecase;
  late _MockCalculateLiquidPsetSizeUsecase calculateLiquidPsetSizeUsecase;
  late _MockCreateChainSwapToExternalUsecase createChainSwapToExternalUsecase;
  late _MockWatchWalletTransactionByTxIdUsecase
  watchWalletTransactionByTxIdUsecase;
  late _MockCalculateBitcoinAbsoluteFeesUsecase
  calculateBitcoinAbsoluteFeesUsecase;
  late _MockUpdateSendSwapLockupFeesUsecase updateSendSwapLockupFeesUsecase;
  late _MockVerifyChainSwapAmountSendUsecase verifyChainSwapAmountSendUsecase;
  late _MockPreviewBitcoinFeeUsecase previewBitcoinFeeUsecase;
  late _MockPreviewBitcoinFeePresetsUsecase previewBitcoinFeePresetsUsecase;
  late _MockCheckLiquidConsolidationUsecase checkLiquidConsolidationUsecase;

  late StreamController<Payjoin> payjoinEvents;

  _TestableSendCubit buildCubit() => _TestableSendCubit(
    labelsFacade: labelsFacade,
    bestWalletUsecase: bestWalletUsecase,
    detectBitcoinStringUsecase: detectBitcoinStringUsecase,
    getSettingsUsecase: getSettingsUsecase,
    convertSatsToCurrencyAmountUsecase: convertSatsUsecase,
    getNetworkFeesUsecase: getNetworkFeesUsecase,
    getWalletUtxosUsecase: getWalletUtxosUsecase,
    getAvailableCurrenciesUsecase: getAvailableCurrenciesUsecase,
    prepareBitcoinSendUsecase: prepareBitcoinSendUsecase,
    prepareLiquidSendUsecase: prepareLiquidSendUsecase,
    sendWithPayjoinUsecase: sendWithPayjoinUsecase,
    watchPayjoinUsecase: watchPayjoinUsecase,
    getWalletsUsecase: getWalletsUsecase,
    getWalletUsecase: getWalletUsecase,
    createSendSwapUsecase: createSendSwapUsecase,
    updatePaidSendSwapUsecase: updatePaidSendSwapUsecase,
    getSwapLimitsUsecase: getSwapLimitsUsecase,
    watchSwapUsecase: watchSwapUsecase,
    watchFinishedWalletSyncsUsecase: watchFinishedWalletSyncsUsecase,
    decodeInvoiceUsecase: decodeInvoiceUsecase,
    signBitcoinTxUsecase: signBitcoinTxUsecase,
    signLiquidTxUsecase: signLiquidTxUsecase,
    broadcastBitcoinTxUsecase: broadcastBitcoinTxUsecase,
    broadcastLiquidTxUsecase: broadcastLiquidTxUsecase,
    calculateLiquidAbsoluteFeesUsecase: calculateLiquidAbsoluteFeesUsecase,
    calculateLiquidPsetSizeUsecase: calculateLiquidPsetSizeUsecase,
    createChainSwapToExternalUsecase: createChainSwapToExternalUsecase,
    watchWalletTransactionByTxIdUsecase: watchWalletTransactionByTxIdUsecase,
    calculateBitcoinAbsoluteFeesUsecase: calculateBitcoinAbsoluteFeesUsecase,
    updateSendSwapLockupFeesUsecase: updateSendSwapLockupFeesUsecase,
    verifyChainSwapAmountSendUsecase: verifyChainSwapAmountSendUsecase,
    previewBitcoinFeeUsecase: previewBitcoinFeeUsecase,
    previewBitcoinFeePresetsUsecase: previewBitcoinFeePresetsUsecase,
    checkLiquidConsolidationUsecase: checkLiquidConsolidationUsecase,
  );

  /// Precondition state that makes [SendState.willAttemptPayjoin] true and
  /// gives `signTransaction` everything its bitcoin payjoin branch reads:
  /// a local-signing bitcoin wallet, a BIP21 request carrying a `pj`
  /// endpoint, payjoin enabled, not a self-send, an unsigned PSBT, a
  /// confirmed amount and a relative fee. [label] is the user's typed note.
  SendState payjoinReadyState({String label = ''}) => SendState(
    step: SendStep.confirm,
    sendType: SendType.bitcoin,
    selectedWallet: _bitcoinLocalWallet(),
    paymentRequest: _payjoinBip21(),
    payjoinGloballyEnabled: true,
    isToSelf: false,
    unsignedPsbt: 'cHNidP8=',
    confirmedAmountSat: 50000,
    label: label,
    selectedFeeOption: FeeSelection.custom,
    customFee: NetworkFee.relativeFromSatPerVbyte(2),
  );

  setUpAll(() {
    registerFallbackValue(_FakeNewLabel());
  });

  setUp(() {
    labelsFacade = _MockLabelsFacade();
    bestWalletUsecase = _MockSelectBestWalletUsecase();
    detectBitcoinStringUsecase = _MockDetectBitcoinStringUsecase();
    getSettingsUsecase = _MockGetSettingsUsecase();
    convertSatsUsecase = _MockConvertSatsToCurrencyAmountUsecase();
    getNetworkFeesUsecase = _MockGetNetworkFeesUsecase();
    getWalletUtxosUsecase = _MockGetWalletUtxosUsecase();
    getAvailableCurrenciesUsecase = _MockGetAvailableCurrenciesUsecase();
    prepareBitcoinSendUsecase = _MockPrepareBitcoinSendUsecase();
    prepareLiquidSendUsecase = _MockPrepareLiquidSendUsecase();
    sendWithPayjoinUsecase = _MockSendWithPayjoinUsecase();
    watchPayjoinUsecase = _MockWatchPayjoinUsecase();
    getWalletsUsecase = _MockGetWalletsUsecase();
    getWalletUsecase = _MockGetWalletUsecase();
    createSendSwapUsecase = _MockCreateSendSwapUsecase();
    updatePaidSendSwapUsecase = _MockUpdatePaidSendSwapUsecase();
    getSwapLimitsUsecase = _MockGetSwapLimitsUsecase();
    watchSwapUsecase = _MockWatchSwapUsecase();
    watchFinishedWalletSyncsUsecase = _MockWatchFinishedWalletSyncsUsecase();
    decodeInvoiceUsecase = _MockDecodeInvoiceUsecase();
    signBitcoinTxUsecase = _MockSignBitcoinTxUsecase();
    signLiquidTxUsecase = _MockSignLiquidTxUsecase();
    broadcastBitcoinTxUsecase = _MockBroadcastBitcoinTransactionUsecase();
    broadcastLiquidTxUsecase = _MockBroadcastLiquidTransactionUsecase();
    calculateLiquidAbsoluteFeesUsecase =
        _MockCalculateLiquidAbsoluteFeesUsecase();
    calculateLiquidPsetSizeUsecase = _MockCalculateLiquidPsetSizeUsecase();
    createChainSwapToExternalUsecase = _MockCreateChainSwapToExternalUsecase();
    watchWalletTransactionByTxIdUsecase =
        _MockWatchWalletTransactionByTxIdUsecase();
    calculateBitcoinAbsoluteFeesUsecase =
        _MockCalculateBitcoinAbsoluteFeesUsecase();
    updateSendSwapLockupFeesUsecase = _MockUpdateSendSwapLockupFeesUsecase();
    verifyChainSwapAmountSendUsecase = _MockVerifyChainSwapAmountSendUsecase();
    previewBitcoinFeeUsecase = _MockPreviewBitcoinFeeUsecase();
    previewBitcoinFeePresetsUsecase = _MockPreviewBitcoinFeePresetsUsecase();
    checkLiquidConsolidationUsecase = _MockCheckLiquidConsolidationUsecase();

    payjoinEvents = StreamController<Payjoin>.broadcast();

    // Benign default stubs for everything the payjoin branch (or its
    // aftermath) touches.
    when(
      () => watchPayjoinUsecase.execute(ids: any(named: 'ids')),
    ).thenAnswer((_) => payjoinEvents.stream);
    when(
      () => getWalletUsecase.execute(any(), sync: any(named: 'sync')),
    ).thenAnswer((_) async => _bitcoinLocalWallet());
    when(() => labelsFacade.store(any())).thenAnswer(
      (_) async => Ok<Label, LabelFailure>(
        Label(
          id: 1,
          type: LabelType.transaction,
          label: 'note',
          reference: 'txid',
        ),
      ),
    );
  });

  tearDown(() async {
    await payjoinEvents.close();
  });

  /// Drives the real `signTransaction` so `_watchPayjoin` gets armed against
  /// the mocked [watchPayjoinUsecase] stream, then returns the cubit.
  Future<_TestableSendCubit> armWatcher(
    _TestableSendCubit cubit, {
    String label = '',
  }) async {
    when(
      () => sendWithPayjoinUsecase.execute(
        walletId: any(named: 'walletId'),
        isTestnet: any(named: 'isTestnet'),
        bip21: any(named: 'bip21'),
        unsignedOriginalPsbt: any(named: 'unsignedOriginalPsbt'),
        amountSat: any(named: 'amountSat'),
        networkFeesSatPerVb: any(named: 'networkFeesSatPerVb'),
      ),
    ).thenAnswer((_) async => _sender(status: PayjoinStatus.requested));

    cubit.setStateForTest(payjoinReadyState(label: label));
    await cubit.signTransaction();
    return cubit;
  }

  group('SendCubit._watchPayjoin', () {
    test('a completed PayjoinSender (real payjoin, txId set) resolves the flow '
        'to success with the payjoin txid, syncs the wallet and stores the '
        'user label on that final txid', () async {
      final cubit = await armWatcher(buildCubit(), label: 'coffee');
      addTearDown(cubit.close);

      // signTransaction set state.txId = originalTxId provisionally.
      expect(cubit.state.txId, 'sender-orig-txid');
      expect(cubit.state.step, SendStep.confirm);

      payjoinEvents.add(
        _sender(status: PayjoinStatus.completed, txId: 'real-payjoin-txid'),
      );
      await pumpEventQueue();

      expect(cubit.state.step, SendStep.success);
      expect(cubit.state.txId, 'real-payjoin-txid');
      // The wallet is synced (sync: true) once the payjoin resolves.
      verify(() => getWalletUsecase.execute('w1', sync: true)).called(1);
      // The typed label is persisted on the FINAL (payjoin) txid.
      final stored =
          verify(() => labelsFacade.store(captureAny())).captured.single
              as NewLabel;
      expect(stored.reference, 'real-payjoin-txid');
      expect(stored.label, 'coffee');
    });

    test('an aborted PayjoinSender (fallback broadcast, txId null) resolves to '
        'success with the ORIGINAL txid', () async {
      final cubit = await armWatcher(buildCubit());
      addTearDown(cubit.close);

      payjoinEvents.add(_sender(status: PayjoinStatus.aborted));
      await pumpEventQueue();

      expect(cubit.state.step, SendStep.success);
      expect(cubit.state.txId, 'sender-orig-txid');
    });

    test('an expired PayjoinSender returns to confirm with a broadcast-failure '
        'exception AND clears both txId and payjoinSender so a retry starts '
        'clean (C7 regression pin)', () async {
      final cubit = await armWatcher(buildCubit());
      addTearDown(cubit.close);

      // The provisional txId + payjoinSender are set before the event.
      expect(cubit.state.txId, 'sender-orig-txid');
      expect(cubit.state.payjoinSender, isNotNull);

      payjoinEvents.add(_sender(status: PayjoinStatus.expired));
      await pumpEventQueue();

      expect(cubit.state.step, SendStep.confirm);
      expect(cubit.state.confirmTransactionException, isNotNull);
      expect(
        cubit.state.confirmTransactionException!.isBroadcastFailure,
        isTrue,
      );
      // The key C7 clear: both must be nulled so broadcastTransaction's
      // `txId != null` guard no longer short-circuits the retry.
      expect(cubit.state.txId, isNull);
      expect(cubit.state.payjoinSender, isNull);
    });

    test(
      'a non-terminal event (requested/proposed) only updates payjoinSender; '
      'the step stays put (not success, not confirm-with-failure)',
      () async {
        final cubit = await armWatcher(buildCubit());
        addTearDown(cubit.close);

        final stepBefore = cubit.state.step;

        payjoinEvents.add(_sender(status: PayjoinStatus.proposed));
        await pumpEventQueue();

        expect(cubit.state.payjoinSender, isNotNull);
        expect(cubit.state.payjoinSender!.status, PayjoinStatus.proposed);
        expect(cubit.state.step, stepBefore);
        expect(cubit.state.step, isNot(SendStep.success));
        expect(cubit.state.confirmTransactionException, isNull);
      },
    );
  });
}
