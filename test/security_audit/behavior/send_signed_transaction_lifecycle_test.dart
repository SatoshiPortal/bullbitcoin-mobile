import '../../features/send/testing/send_spend_test_double.dart';

import 'package:spend/testing.dart';
import 'package:bb_mobile/features/send/domain/usecases/load_send_display_preferences_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/load_send_network_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/retry_payjoin_proposal_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' as app;
import 'package:primitives/primitives.dart' show ConvertAmount, Ok, ScriptType;
import 'package:bb_mobile/features/send/domain/usecases/prepare_send_bitcoin_transaction_usecase.dart';

// Behavioral proof for two audit findings on SendCubit:
//
// 1. `_invalidateSignedTransaction()` (added by `fix(send)`) only clears
//    `signedBitcoinTx`. The BDK path stores its signed payload in
//    `signedBitcoinPsbt`, which survives every payment edit and is the value
//    `onConfirmTransactionClicked()` broadcasts.
// 2. `broadcastTransaction()` guards its `emit`s with `isClosed` but still
//    dereferences `state.txId!` for the post-broadcast bookkeeping, so a cubit
//    closed mid-broadcast throws instead of recording the send.
import 'dart:async';

import 'package:bb_mobile/features/send/domain/usecases/create_boltz_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_swap_route_usecase.dart';
import 'package:swaps/swaps.dart'
    show
        CreateBitcoinToLiquidSwapUsecase,
        CreateLiquidToBitcoinSwapUsecase,
        GetSwapLimitsAndFeesUsecase,
        DropPendingSwapLockupUsecase,
        RecordPendingSwapLockupUsecase,
        RecordSwapLockupUsecase,
        WatchSwapUsecase;
import 'package:bb_mobile/features/send/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:primitives/primitives.dart' show SignerEntity;
import 'package:fees/fees.dart';
import 'package:bb_mobile/features/coins/domain/wallet_utxo.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/send/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:send/send.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/validate_bitcoin_selection_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:transactions/transactions.dart';
import 'package:labels/labels.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_pset_size_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_cross_chain_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_swap_usecase.dart';
import 'package:address_view/payment_destination.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_cross_chain_quote_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_swap_quote_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/resolve_lightning_address_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/resolve_selected_inputs_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/select_best_wallet_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/update_send_swap_payin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/validate_coin_control_payment_request_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/verify_exchange_payin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/verify_send_signed_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_payjoin_original_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_visible_payjoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_adoptable_payjoin_sender_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_sp_payment_for_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/refresh_sp_wallet_for_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/send_sp_payment_for_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_sp_network_for_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/validate_sp_amount_for_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/validate_sp_recipient_for_send_usecase.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bb_mobile/features/send/presentation/send_wallet_view.dart';
import 'package:bb_mobile/features/send/domain/usecases/load_send_label_suggestions_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/store_send_transaction_label_usecase.dart';

class _MockLabels extends Mock implements Labels {}

class _MockPayjoinSessions extends Mock implements PayjoinSessions {}

class _MockSelectBestWalletUsecase extends Mock
    implements SelectBestWalletUsecase {}

class _MockDetectBitcoinStringUsecase extends Mock
    implements DetectBitcoinStringUsecase {}

class _MockPreferences extends Mock implements Preferences {}

class _MockSend extends Mock implements Send {}

class _MockFees extends Mock implements Fees {}

class _MockGetWalletUtxosUsecase extends Mock
    implements GetWalletUtxosUsecase {}

class _MockPrepareBitcoinSendUsecase extends Mock
    implements PrepareSendBitcoinTransactionUsecase {}

class _MockValidateBitcoinSelectionUsecase extends Mock
    implements ValidateBitcoinSelectionUsecase {}

class _MockPrepareLiquidSendUsecase extends Mock
    implements PrepareLiquidSendUsecase {}

class _MockSignBitcoinTxUsecase extends Mock implements SignBitcoinTxUsecase {}

class _MockSignLiquidTxUsecase extends Mock implements SignLiquidTxUsecase {}

class _MockBroadcastBitcoinTransactionUsecase extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

class _MockBroadcastLiquidTransactionUsecase extends Mock
    implements BroadcastLiquidTransactionUsecase {}

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class _MockCreateSendSwapUsecase extends Mock
    implements CreateSendSwapUsecase {}

class _MockGetSwapLimitsAndFeesUsecase extends Mock
    implements GetSwapLimitsAndFeesUsecase {}

class _MockCreateBitcoinToLiquidSwapUsecase extends Mock
    implements CreateBitcoinToLiquidSwapUsecase {}

class _MockCreateLiquidToBitcoinSwapUsecase extends Mock
    implements CreateLiquidToBitcoinSwapUsecase {}

class _MockGetSendSwapQuoteUsecase extends Mock
    implements GetSendSwapQuoteUsecase {}

class _MockCreateSendCrossChainSwapUsecase extends Mock
    implements CreateSendCrossChainSwapUsecase {}

class _MockGetSendCrossChainQuoteUsecase extends Mock
    implements GetSendCrossChainQuoteUsecase {}

class _MockResolveLightningAddressUsecase extends Mock
    implements ResolveLightningAddressUsecase {}

class _MockUpdateSendSwapPayinUsecase extends Mock
    implements UpdateSendSwapPayinUsecase {}

class _MockWatchSendSwapUsecase extends Mock implements WatchSendSwapUsecase {}

class _MockSendWithPayjoinUsecase extends Mock
    implements SendWithPayjoinUsecase {}

class _MockWatchPayjoinUsecase extends Mock implements WatchPayjoinUsecase {}

class _MockGetAdoptablePayjoinSenderUsecase extends Mock
    implements GetAdoptablePayjoinSenderUsecase {}

class _MockBroadcastPayjoinOriginalUsecase extends Mock
    implements BroadcastPayjoinOriginalUsecase {}

class _MockGetVisiblePayjoinTransactionUsecase extends Mock
    implements GetVisiblePayjoinTransactionUsecase {}

class _MockWatchFinishedWalletSyncsUsecase extends Mock
    implements WatchFinishedWalletSyncsUsecase {}

class _MockCalculateLiquidAbsoluteFeesUsecase extends Mock
    implements CalculateLiquidAbsoluteFeesUsecase {}

class _MockCalculateLiquidPsetSizeUsecase extends Mock
    implements CalculateLiquidPsetSizeUsecase {}

class _MockWatchWalletTransactionByTxIdUsecase extends Mock
    implements Transactions {}

class _MockCalculateBitcoinAbsoluteFeesUsecase extends Mock
    implements CalculateBitcoinAbsoluteFeesUsecase {}

class _MockVerifyChainSwapAmountSendUsecase extends Mock
    implements VerifyChainSwapAmountSendUsecase {}

class _MockVerifyExchangePayinUsecase extends Mock
    implements VerifyExchangePayinUsecase {}

class _MockPreviewBitcoinFeeUsecase extends Mock
    implements PreviewBitcoinFeeUsecase {}

class _MockPreviewBitcoinFeePresetsUsecase extends Mock
    implements PreviewBitcoinFeePresetsUsecase {}

class _MockConsolidation extends Mock implements Consolidation {}

class _MockGetSendPayjoinEnabledUsecase extends Mock
    implements GetSendPayjoinEnabledUsecase {}

class _MockVerifySignedTxUsecase extends Mock
    implements VerifySendSignedTxUsecase {}

/// Exposes `emit` so a test can start from a realistic mid-flow state.
class _MockValidateSpRecipientForSendUsecase extends Mock
    implements ValidateSpRecipientForSendUsecase {}

class _MockValidateSpAmountForSendUsecase extends Mock
    implements ValidateSpAmountForSendUsecase {}

class _MockGetSpNetworkForSendUsecase extends Mock
    implements GetSpNetworkForSendUsecase {}

class _MockPrepareSpPaymentForSendUsecase extends Mock
    implements PrepareSpPaymentForSendUsecase {}

class _MockSendSpPaymentForSendUsecase extends Mock
    implements SendSpPaymentForSendUsecase {}

class _MockRefreshSpWalletForSendUsecase extends Mock
    implements RefreshSpWalletForSendUsecase {}

class _MockGetSendSwapRouteUsecase extends Mock
    implements GetSendSwapRouteUsecase {}

class _MockCreateBoltzSendSwapUsecase extends Mock
    implements CreateBoltzSendSwapUsecase {}

class _MockRecordSwapLockupUsecase extends Mock
    implements RecordSwapLockupUsecase {}

class _MockWatchSwapUsecase extends Mock implements WatchSwapUsecase {}

class _MockRecordPendingSwapLockupUsecase extends Mock
    implements RecordPendingSwapLockupUsecase {}

class _MockDropPendingSwapLockupUsecase extends Mock
    implements DropPendingSwapLockupUsecase {}

class _TestSendCubit extends SendCubit {
  _TestSendCubit({
    required super.loadSendLabelSuggestions,
    required super.storeSendTransactionLabel,
    required super.bestWalletUsecase,
    required super.detectBitcoinStringUsecase,
    required super.loadPreferencesUsecase,
    required super.readExchangeRate,
    required super.loadNetworkFeesUsecase,
    required super.getWalletUtxosUsecase,
    required super.validateBitcoinSelectionUsecase,
    required super.spend,
    required super.prepareLiquidSendUsecase,
    required super.signLiquidTxUsecase,
    required super.broadcastLiquidTxUsecase,
    required super.getWalletsUsecase,
    required super.getWalletUsecase,
    required super.createSendSwapUsecase,
    required super.getSendSwapQuoteUsecase,
    required super.createSendCrossChainSwapUsecase,
    required super.getSendCrossChainQuoteUsecase,
    required super.resolveLightningAddressUsecase,
    required super.updateSendSwapPayinUsecase,
    required super.watchSendSwapUsecase,
    required super.sendWithPayjoinUsecase,
    required super.watchPayjoinUsecase,
    required super.getAdoptablePayjoinSenderUsecase,
    required super.broadcastPayjoinOriginalUsecase,
    required super.getVisiblePayjoinTransactionUsecase,
    required super.retryPayjoinProposalUsecase,
    required super.watchFinishedWalletSyncsUsecase,
    required super.calculateLiquidAbsoluteFeesUsecase,
    required super.calculateLiquidPsetSizeUsecase,
    required super.transactions,
    required super.verifyChainSwapAmountSendUsecase,
    required super.verifyExchangePayinUsecase,
    required super.consolidation,
    required super.getSendPayjoinEnabledUsecase,
    required super.validateSpRecipientForSendUsecase,
    required super.validateSpAmountForSendUsecase,
    required super.getSpNetworkForSendUsecase,
    required super.prepareSpPaymentForSendUsecase,
    required super.sendSpPaymentForSendUsecase,
    required super.refreshSpWalletForSendUsecase,
    required super.resolveSelectedInputsUsecase,
    required super.validateCoinControlPaymentRequestUsecase,
    required super.getSendSwapRouteUsecase,
    required super.createBoltzSendSwapUsecase,
    required super.recordSwapLockupUsecase,
    required super.recordPendingSwapLockupUsecase,
    required super.dropPendingSwapLockupUsecase,
    required super.watchSwapUsecase,
    required super.getSwapLimitsAndFeesUsecase,
    required super.createBitcoinToLiquidSwapUsecase,
    required super.createLiquidToBitcoinSwapUsecase,
  });

  void seed(SendState state) {
    final signed = state.signedBitcoinPsbt ?? state.signedBitcoinTx;
    emit(
      state.copyWith(
        bitcoinSignature: signed == null
            ? null
            : SpendFixtures.signedBitcoin(signed),
      ),
    );
  }
}

final _wallet = Wallet(
  origin: 'wpkh([aabbccdd/84h/0h/0h])',
  label: 'Secure Bitcoin',
  network: Network.bitcoinMainnet,
  isDefault: true,
  masterFingerprint: 'aabbccdd',
  xpubFingerprint: 'aabbccdd',
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: 'desc',
  internalPublicDescriptor: 'desc',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(1000000),
);

void main() {
  late _MockBroadcastBitcoinTransactionUsecase broadcastBitcoinTx;
  late _MockLabels labelsFacade;
  late _MockGetWalletUsecase getWalletUsecase;
  late _MockGetWalletUtxosUsecase getWalletUtxosUsecase;
  late _MockConsolidation consolidation;
  late _MockPrepareLiquidSendUsecase prepareLiquidSendUsecase;
  late _MockValidateBitcoinSelectionUsecase validateBitcoinSelectionUsecase;
  late _MockCalculateLiquidAbsoluteFeesUsecase
  calculateLiquidAbsoluteFeesUsecase;
  late _TestSendCubit cubit;

  setUpAll(() {
    registerFallbackValue(
      NewLabel.tx(transactionId: 'fallback', label: 'fallback'),
    );
    registerFallbackValue(const RelativeFee(250));
  });

  setUp(() {
    broadcastBitcoinTx = _MockBroadcastBitcoinTransactionUsecase();
    labelsFacade = _MockLabels();
    getWalletUsecase = _MockGetWalletUsecase();
    getWalletUtxosUsecase = _MockGetWalletUtxosUsecase();
    consolidation = _MockConsolidation();
    prepareLiquidSendUsecase = _MockPrepareLiquidSendUsecase();
    validateBitcoinSelectionUsecase = _MockValidateBitcoinSelectionUsecase();
    calculateLiquidAbsoluteFeesUsecase =
        _MockCalculateLiquidAbsoluteFeesUsecase();
    when(
      () => validateBitcoinSelectionUsecase.execute(
        walletId: any(named: 'walletId'),
        selectedInputs: any(named: 'selectedInputs'),
      ),
    ).thenAnswer((_) async => []);

    cubit = _TestSendCubit(
      loadSendLabelSuggestions: LoadSendLabelSuggestionsUsecase(labelsFacade),
      storeSendTransactionLabel: StoreSendTransactionLabelUsecase(labelsFacade),
      bestWalletUsecase: _MockSelectBestWalletUsecase(),
      detectBitcoinStringUsecase: _MockDetectBitcoinStringUsecase(),
      loadPreferencesUsecase: LoadSendDisplayPreferencesUsecase(
        _MockPreferences(),
      ),
      readExchangeRate: _MockSend().exchangeRate,
      loadNetworkFeesUsecase: LoadSendNetworkFeesUsecase(fees: _MockFees()),
      getWalletUtxosUsecase: getWalletUtxosUsecase,
      spend: SendSpendTestDouble(
        read: () => cubit.state,
        prepare: _MockPrepareBitcoinSendUsecase(),
        sign: _MockSignBitcoinTxUsecase(),
        broadcast: broadcastBitcoinTx,
        fees: _MockCalculateBitcoinAbsoluteFeesUsecase(),
        preview: _MockPreviewBitcoinFeeUsecase(),
        presets: _MockPreviewBitcoinFeePresetsUsecase(),
        verify: _MockVerifySignedTxUsecase(),
      ),
      validateBitcoinSelectionUsecase: validateBitcoinSelectionUsecase,
      prepareLiquidSendUsecase: prepareLiquidSendUsecase,
      signLiquidTxUsecase: _MockSignLiquidTxUsecase(),
      broadcastLiquidTxUsecase: _MockBroadcastLiquidTransactionUsecase(),
      getWalletsUsecase: _MockGetWalletsUsecase(),
      getWalletUsecase: getWalletUsecase,
      createSendSwapUsecase: _MockCreateSendSwapUsecase(),
      getSendSwapQuoteUsecase: _MockGetSendSwapQuoteUsecase(),
      createSendCrossChainSwapUsecase: _MockCreateSendCrossChainSwapUsecase(),
      getSendCrossChainQuoteUsecase: _MockGetSendCrossChainQuoteUsecase(),
      resolveLightningAddressUsecase: _MockResolveLightningAddressUsecase(),
      updateSendSwapPayinUsecase: _MockUpdateSendSwapPayinUsecase(),
      watchSendSwapUsecase: _MockWatchSendSwapUsecase(),
      sendWithPayjoinUsecase: _MockSendWithPayjoinUsecase(),
      watchPayjoinUsecase: _MockWatchPayjoinUsecase(),
      getAdoptablePayjoinSenderUsecase: _MockGetAdoptablePayjoinSenderUsecase(),
      broadcastPayjoinOriginalUsecase: _MockBroadcastPayjoinOriginalUsecase(),
      getVisiblePayjoinTransactionUsecase:
          _MockGetVisiblePayjoinTransactionUsecase(),
      retryPayjoinProposalUsecase: _MockRetryPayjoinProposalUsecase(),
      watchFinishedWalletSyncsUsecase: _MockWatchFinishedWalletSyncsUsecase(),
      calculateLiquidAbsoluteFeesUsecase: calculateLiquidAbsoluteFeesUsecase,
      calculateLiquidPsetSizeUsecase: _MockCalculateLiquidPsetSizeUsecase(),
      transactions: _MockWatchWalletTransactionByTxIdUsecase(),
      verifyChainSwapAmountSendUsecase: _MockVerifyChainSwapAmountSendUsecase(),
      verifyExchangePayinUsecase: _MockVerifyExchangePayinUsecase(),
      consolidation: consolidation,
      getSendPayjoinEnabledUsecase: _MockGetSendPayjoinEnabledUsecase(),
      validateSpRecipientForSendUsecase:
          _MockValidateSpRecipientForSendUsecase(),
      validateSpAmountForSendUsecase: _MockValidateSpAmountForSendUsecase(),
      getSpNetworkForSendUsecase: _MockGetSpNetworkForSendUsecase(),
      prepareSpPaymentForSendUsecase: _MockPrepareSpPaymentForSendUsecase(),
      sendSpPaymentForSendUsecase: _MockSendSpPaymentForSendUsecase(),
      refreshSpWalletForSendUsecase: _MockRefreshSpWalletForSendUsecase(),
      resolveSelectedInputsUsecase: ResolveSelectedInputsUsecase(
        _MockPayjoinSessions(),
      ),
      validateCoinControlPaymentRequestUsecase:
          ValidateCoinControlPaymentRequestUsecase(),
      getSendSwapRouteUsecase: _MockGetSendSwapRouteUsecase(),
      createBoltzSendSwapUsecase: _MockCreateBoltzSendSwapUsecase(),
      recordSwapLockupUsecase: _MockRecordSwapLockupUsecase(),
      recordPendingSwapLockupUsecase: _MockRecordPendingSwapLockupUsecase(),
      dropPendingSwapLockupUsecase: _MockDropPendingSwapLockupUsecase(),
      watchSwapUsecase: _MockWatchSwapUsecase(),
      getSwapLimitsAndFeesUsecase: _MockGetSwapLimitsAndFeesUsecase(),
      createBitcoinToLiquidSwapUsecase: _MockCreateBitcoinToLiquidSwapUsecase(),
      createLiquidToBitcoinSwapUsecase: _MockCreateLiquidToBitcoinSwapUsecase(),
    );
  });

  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
  });

  group('signed payload invalidation', () {
    test('going back to edit the payment drops the signed BDK PSBT', () {
      cubit.seed(
        const SendState(
          step: SendStep.confirm,
          unsignedPsbt: 'cHNidP8BAHECAAAA-unsigned',
          signedBitcoinPsbt: 'cHNidP8BAHECAAAA-signed',
        ),
      );

      cubit.backClicked();

      expect(
        cubit.state.signedBitcoinPsbt,
        isNull,
        reason: 'a payment edit must never leave a broadcastable signed PSBT',
      );
    });

    test('changing the amount drops the signed BDK PSBT', () async {
      cubit.seed(
        const SendState(
          step: SendStep.amount,
          amount: '1000',
          signedBitcoinPsbt: 'cHNidP8BAHECAAAA-signed',
        ),
      );

      await cubit.amountChanged(amount: '999999');

      expect(cubit.state.signedBitcoinPsbt, isNull);
    });
  });

  group('send MAX', () {
    // No input currency, and a fiat one: a fiat input must not make MAX fail.
    for (final (inputCode, rate) in [('', null), ('CAD', 100000.0)]) {
      test('caps MAX at the spendable balance, excluding frozen coins '
          '(input "$inputCode")', () async {
        const walletBalanceSat = 140000;
        const frozenSat = 40000;
        const absoluteFeesSat = 500;

        final liquidWallet = Wallet(
          origin: 'ct(slip77(..))',
          label: 'Instant payments',
          network: Network.liquidMainnet,
          isDefault: true,
          masterFingerprint: 'aabbccdd',
          xpubFingerprint: 'aabbccdd',
          scriptType: ScriptType.bip84,
          xpub: 'xpub',
          externalPublicDescriptor: 'desc',
          internalPublicDescriptor: 'desc',
          signer: SignerEntity.local,
          signerDevice: null,
          balanceSat: BigInt.from(walletBalanceSat),
        );

        WalletUtxo utxo({required int amountSat, required bool isFrozen}) =>
            WalletUtxo.liquid(
              walletId: liquidWallet.id,
              txId: 'utxo-$amountSat',
              vout: 0,
              scriptPubkey: '00',
              amountSat: BigInt.from(amountSat),
              standardAddress: 'ex1qstandard',
              confidentialAddress: 'lq1qconfidential',
              isFrozen: isFrozen,
            );

        when(
          () => getWalletUtxosUsecase.execute(walletId: any(named: 'walletId')),
        ).thenAnswer(
          (_) async => [
            utxo(amountSat: walletBalanceSat - frozenSat, isFrozen: false),
            utxo(amountSat: frozenSat, isFrozen: true),
          ],
        );
        when(() => consolidation.isRequired(any()))
            .thenAnswer((_) async => const Ok(false));
        when(
          () => prepareLiquidSendUsecase.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
            feeRate: any(named: 'feeRate'),
            amountSat: any(named: 'amountSat'),
            drain: any(named: 'drain'),
            hasFrozenInputs: true,
          ),
        ).thenAnswer((_) async => const Ok('pset-base64'));
        when(
          () => calculateLiquidAbsoluteFeesUsecase.execute(
            pset: any(named: 'pset'),
          ),
        ).thenAnswer((_) async => absoluteFeesSat);

        // RelativeFee carries sat/kwu: 500 = 2 sat/vB, 25 = the 0.1 relay floor.
        const feeOptions = FeeOptions(
          fastest: RelativeFee(500),
          economic: RelativeFee(250),
          slow: RelativeFee(250),
          minRelay: RelativeFee(25),
        );

        cubit.seed(
          SendState(
            step: SendStep.amount,
            selectedWallet: SendWalletBitcoin(liquidWallet),
            sendMax: true,
            copiedRawPaymentRequest: 'ex1qrecipient',
            bitcoinFeesList: feeOptions,
            liquidFeesList: feeOptions,
            inputAmountCurrencyCode: inputCode,
            exchangeRate: rate,
          ),
        );

        await cubit.createTransaction();

        expect(
          cubit.state.confirmedAmountSat,
          walletBalanceSat - frozenSat - absoluteFeesSat,
          reason: 'frozen coins are not spendable, so MAX cannot include them',
        );
        expect(cubit.state.failure, isNull);
        if (rate != null) {
          expect(
            cubit.state.amount,
            ConvertAmount.satsToFiat(
              walletBalanceSat - frozenSat - absoluteFeesSat,
              rate,
            ).toString(),
          );
        }
      });
    }
  });

  group('broadcast bookkeeping', () {
    test('a cubit closed mid-broadcast still records the send', () async {
      final broadcast = Completer<String>();
      when(
        () => broadcastBitcoinTx.execute(
          walletId: _wallet.id,
          any(),
          isPsbt: any(named: 'isPsbt'),
          network: app.Network.bitcoinMainnet,
        ),
      ).thenAnswer((_) => broadcast.future);
      when(() => labelsFacade.store(any())).thenAnswer(
        (invocation) async =>
            Ok(Label.tx(id: 1, transactionId: 'broadcast-txid', label: 'rent')),
      );
      when(() => getWalletUsecase.execute(any(), sync: any(named: 'sync')))
          .thenAnswer((_) async => _wallet);

      cubit.seed(
        SendState(
          step: SendStep.sending,
          selectedWallet: SendWalletBitcoin(_wallet),
          signedBitcoinPsbt: 'cHNidP8BAHECAAAA-signed',
          label: 'rent',
        ),
      );

      final pending = cubit.broadcastTransaction();
      await cubit.close();
      broadcast.complete('broadcast-txid');

      await expectLater(
        pending,
        completes,
        reason: 'closing the screen must not turn a broadcast into a crash',
      );
      verify(() => labelsFacade.store(any())).called(1);
    });
  });
}

class _MockRetryPayjoinProposalUsecase extends Mock
    implements RetryPayjoinProposalUsecase {}
