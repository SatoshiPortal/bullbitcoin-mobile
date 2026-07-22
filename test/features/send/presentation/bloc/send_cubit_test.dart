import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/create_chain_swap_to_external_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/decode_invoice_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/update_send_swap_lockup_fees_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
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

/// Thin subclass exposing the protected `emit` so the test can seed an
/// arbitrary state (e.g. "already signed by Trezor") without driving the
/// whole address/amount UI flow through the cubit's public API.
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
  });

  void seed(SendState state) => emit(state);
}

void main() {
  late _MockLabelsFacade labelsFacade;
  late _MockSelectBestWalletUsecase bestWalletUsecase;
  late _MockDetectBitcoinStringUsecase detectBitcoinStringUsecase;
  late _MockGetSettingsUsecase getSettingsUsecase;
  late _MockConvertSatsToCurrencyAmountUsecase
  convertSatsToCurrencyAmountUsecase;
  late _MockGetNetworkFeesUsecase getNetworkFeesUsecase;
  late _MockGetWalletUtxosUsecase getWalletUtxosUsecase;
  late _MockGetAvailableCurrenciesUsecase getAvailableCurrenciesUsecase;
  late _MockPrepareBitcoinSendUsecase prepareBitcoinSendUsecase;
  late _MockPrepareLiquidSendUsecase prepareLiquidSendUsecase;
  late _MockSendWithPayjoinUsecase sendWithPayjoinUsecase;
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

  late _TestableSendCubit cubit;

  final trezorWallet = Wallet(
    origin: 'trezor-1',
    network: Network.bitcoinMainnet,
    xpubFingerprint: 'aabbccdd',
    scriptType: ScriptType.bip84,
    xpub: 'zpub-fixture',
    externalPublicDescriptor: 'wpkh-external-fixture',
    internalPublicDescriptor: 'wpkh-internal-fixture',
    signer: SignerEntity.remote,
    signerDevice: SignerDeviceEntity.trezor,
    balanceSat: BigInt.from(1000000),
  );

  final bitcoinFees = FeeOptions(
    fastest: NetworkFee.relativeFromSatPerVbyte(5),
    economic: NetworkFee.relativeFromSatPerVbyte(2),
    slow: NetworkFee.relativeFromSatPerVbyte(1),
    minRelay: NetworkFee.relativeFromSatPerVbyte(0.1),
  );

  setUpAll(() {
    registerFallbackValue(NetworkFee.relativeFromSatPerVbyte(1));
  });

  setUp(() {
    labelsFacade = _MockLabelsFacade();
    bestWalletUsecase = _MockSelectBestWalletUsecase();
    detectBitcoinStringUsecase = _MockDetectBitcoinStringUsecase();
    getSettingsUsecase = _MockGetSettingsUsecase();
    convertSatsToCurrencyAmountUsecase =
        _MockConvertSatsToCurrencyAmountUsecase();
    getNetworkFeesUsecase = _MockGetNetworkFeesUsecase();
    getWalletUtxosUsecase = _MockGetWalletUtxosUsecase();
    getAvailableCurrenciesUsecase = _MockGetAvailableCurrenciesUsecase();
    prepareBitcoinSendUsecase = _MockPrepareBitcoinSendUsecase();
    prepareLiquidSendUsecase = _MockPrepareLiquidSendUsecase();
    sendWithPayjoinUsecase = _MockSendWithPayjoinUsecase();
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

    cubit = _TestableSendCubit(
      labelsFacade: labelsFacade,
      bestWalletUsecase: bestWalletUsecase,
      detectBitcoinStringUsecase: detectBitcoinStringUsecase,
      getSettingsUsecase: getSettingsUsecase,
      convertSatsToCurrencyAmountUsecase: convertSatsToCurrencyAmountUsecase,
      getNetworkFeesUsecase: getNetworkFeesUsecase,
      getWalletUtxosUsecase: getWalletUtxosUsecase,
      getAvailableCurrenciesUsecase: getAvailableCurrenciesUsecase,
      prepareBitcoinSendUsecase: prepareBitcoinSendUsecase,
      prepareLiquidSendUsecase: prepareLiquidSendUsecase,
      sendWithPayjoinUsecase: sendWithPayjoinUsecase,
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
    );

    when(
      () => getWalletUtxosUsecase.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => []);
    when(
      () => prepareBitcoinSendUsecase.execute(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        networkFee: any(named: 'networkFee'),
        amountSat: any(named: 'amountSat'),
        replaceByFee: any(named: 'replaceByFee'),
        selectedInputs: any(named: 'selectedInputs'),
        drain: any(named: 'drain'),
      ),
    ).thenAnswer(
      (_) async =>
          (unsignedPsbt: 'unsigned-psbt-for-B', txSize: 110, isToSelf: false),
    );
    when(
      () =>
          calculateBitcoinAbsoluteFeesUsecase.execute(psbt: any(named: 'psbt')),
    ).thenAnswer((_) async => 550);
  });

  group('SendCubit.createTransaction — stale signature invalidation', () {
    test(
      'clears a previously Trezor-signed tx when the PSBT is rebuilt for '
      'an edited (post-back) transaction, so onConfirmTransactionClicked '
      'cannot broadcast the old transaction instead of the one on screen',
      () async {
        // Arrange: transaction A was already built, sent to Trezor, signed,
        // and finalized (`signedBitcoinTx` populated via
        // `updateSignedBitcoinTx`, mirroring `SignTrezorButton`'s callback)
        // — exactly the state left behind right before the user clicks
        // "back" and edits the amount/recipient to produce transaction B.
        cubit.seed(
          SendState(
            step: SendStep.confirm,
            sendType: SendType.bitcoin,
            selectedWallet: trezorWallet,
            bitcoinFeesList: bitcoinFees,
            liquidFeesList: bitcoinFees,
            scannedRawPaymentRequest: 'bc1qexampleaddressforfixture',
            confirmedAmountSat: 50000,
            unsignedPsbt: 'unsigned-psbt-for-A',
            signedBitcoinTx: 'raw-signed-hex-for-A',
          ),
        );
        expect(cubit.state.signedBitcoinTx, 'raw-signed-hex-for-A');

        // Act: the user is back on the confirm step after editing — the
        // amount/recipient screens always funnel back through
        // `createTransaction()` (via `onAmountConfirmed`) to rebuild the
        // unsigned PSBT for whatever is currently on screen (B).
        await cubit.createTransaction();

        // Assert: A's finalized signature must never survive the rebuild.
        // Before the fix, `createTransaction()` never touched
        // `signedBitcoinTx` for a remote-signing (hardware) wallet, so this
        // would still read 'raw-signed-hex-for-A' here — meaning
        // `onConfirmTransactionClicked` would see a non-null
        // `signedBitcoinTx` and broadcast A while showing B on screen.
        expect(cubit.state.signedBitcoinTx, isNull);
        expect(cubit.state.signedBitcoinPsbt, isNull);
        // The PSBT actually built for what's on screen now is B's.
        expect(cubit.state.unsignedPsbt, 'unsigned-psbt-for-B');
      },
    );
  });

  group('SendCubit.backClicked — stale signature invalidation', () {
    test('clears a finalized signature when leaving confirm to edit the '
        'amount/recipient', () {
      cubit.seed(
        SendState(
          step: SendStep.confirm,
          selectedWallet: trezorWallet,
          signedBitcoinTx: 'raw-signed-hex-for-A',
          signedBitcoinPsbt: 'signed-psbt-for-A',
        ),
      );

      cubit.backClicked();

      expect(cubit.state.step, SendStep.amount);
      expect(cubit.state.signedBitcoinTx, isNull);
      expect(cubit.state.signedBitcoinPsbt, isNull);
    });
  });
}
