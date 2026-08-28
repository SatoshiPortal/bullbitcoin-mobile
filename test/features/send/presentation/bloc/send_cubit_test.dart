import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_transaction_recipient.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/insufficient_funds_exception.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/core/wallet/domain/selected_inputs_unavailable_exception.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/validate_bitcoin_selection_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_pset_size_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_cross_chain_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_cross_chain_quote_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_swap_quote_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/resolve_lightning_address_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/resolve_sweep_inputs_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/select_best_wallet_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/update_paid_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/verify_exchange_payin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/update_send_swap_payin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/verify_send_signed_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/validate_sweep_payment_request_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_send_swap_usecase.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Sats;

import '../../../coins/wallet_utxo_fixture.dart';

class _MockLabelsFacade extends Mock implements LabelsFacade {}

class _MockSelectBestWalletUsecase extends Mock
    implements SelectBestWalletUsecase {}

class _MockDetectBitcoinStringUsecase extends Mock
    implements DetectBitcoinStringUsecase {}

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockChainSwap extends Mock implements ChainSwap {}

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

class _MockValidateBitcoinSelectionUsecase extends Mock
    implements ValidateBitcoinSelectionUsecase {}

class _MockPrepareLiquidSendUsecase extends Mock
    implements PrepareLiquidSendUsecase {}

class _MockSendWithPayjoinUsecase extends Mock
    implements SendWithPayjoinUsecase {}

class _MockWatchPayjoinUsecase extends Mock implements WatchPayjoinUsecase {}

class _MockPayjoinSessions extends Mock implements PayjoinSessions {}

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class _MockCreateSendSwapUsecase extends Mock
    implements CreateSendSwapUsecase {}

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

class _MockOrderSwapQuote extends Mock implements OrderSwapQuote {}

class _MockOrderSwapRecord extends Mock implements OrderSwapRecord {}

class _MockUpdatePaidSendSwapUsecase extends Mock
    implements UpdatePaidSendSwapUsecase {}

class _MockWatchFinishedWalletSyncsUsecase extends Mock
    implements WatchFinishedWalletSyncsUsecase {}

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

class _MockWatchWalletTransactionByTxIdUsecase extends Mock
    implements WatchWalletTransactionByTxIdUsecase {}

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

class _MockCheckLiquidConsolidationUsecase extends Mock
    implements CheckLiquidConsolidationUsecase {}

class _MockGetSendPayjoinEnabledUsecase extends Mock
    implements GetSendPayjoinEnabledUsecase {}

class _MockVerifySignedTxUsecase extends Mock
    implements VerifySendSignedTxUsecase {}

class _FakeNewLabel extends Fake implements NewLabel {}

/// Test seam: [SendCubit]'s payjoin watcher ([_watchPayjoin]) is private and
/// only started from the tail of the public [SendCubit.signTransaction]. This
/// subclass exposes [emit] so a test can stage exactly the precondition state
/// that drives `signTransaction` into its payjoin branch — nothing about the
/// production class is changed; the tests exercise the real
/// `signTransaction` → `_watchPayjoin` code path.
class _TestableSendCubit extends SendCubit {
  _TestableSendCubit({
    super.wallet,
    super.initialSweepOutpoints,
    required super.labelsFacade,
    required super.bestWalletUsecase,
    required super.detectBitcoinStringUsecase,
    required super.getSettingsUsecase,
    required super.convertSatsToCurrencyAmountUsecase,
    required super.getNetworkFeesUsecase,
    required super.getWalletUtxosUsecase,
    required super.getAvailableCurrenciesUsecase,
    required super.prepareBitcoinSendUsecase,
    required super.validateBitcoinSelectionUsecase,
    required super.prepareLiquidSendUsecase,
    required super.sendWithPayjoinUsecase,
    required super.watchPayjoinUsecase,
    required super.getWalletsUsecase,
    required super.getWalletUsecase,
    required super.createSendSwapUsecase,
    required super.getSendSwapQuoteUsecase,
    required super.createSendCrossChainSwapUsecase,
    required super.getSendCrossChainQuoteUsecase,
    required super.resolveLightningAddressUsecase,
    required super.updateSendSwapPayinUsecase,
    required super.watchSendSwapUsecase,
    required super.updatePaidSendSwapUsecase,
    required super.watchFinishedWalletSyncsUsecase,
    required super.signBitcoinTxUsecase,
    required super.signLiquidTxUsecase,
    required super.broadcastBitcoinTxUsecase,
    required super.broadcastLiquidTxUsecase,
    required super.calculateLiquidAbsoluteFeesUsecase,
    required super.calculateLiquidPsetSizeUsecase,
    required super.watchWalletTransactionByTxIdUsecase,
    required super.calculateBitcoinAbsoluteFeesUsecase,
    required super.verifyChainSwapAmountSendUsecase,
    required super.verifyExchangePayinUsecase,
    required super.previewBitcoinFeeUsecase,
    required super.previewBitcoinFeePresetsUsecase,
    required super.checkLiquidConsolidationUsecase,
    required super.getSendPayjoinEnabledUsecase,
    required super.verifySignedTxUsecase,
    required super.resolveSweepInputsUsecase,
    required super.validateSweepPaymentRequestUsecase,
    super.parsePaymentRequest,
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

Wallet _liquidWallet({required int balanceSat}) => Wallet(
  origin: 'w-liquid',
  network: Network.liquidMainnet,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(balanceSat),
);

Wallet _bitcoinWallet({required int balanceSat}) => Wallet(
  origin: 'w-bitcoin',
  network: Network.bitcoinMainnet,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(balanceSat),
);

Wallet _bitcoinWatchOnlyWallet() => Wallet(
  origin: 'w1',
  network: Network.bitcoinMainnet,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.none,
  signerDevice: null,
  balanceSat: BigInt.from(1000000),
);

Wallet _bitcoinHardwareWallet() => Wallet(
  origin: 'w1',
  network: Network.bitcoinMainnet,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.remote,
  signerDevice: SignerDeviceEntity.ledgerNanoX,
  balanceSat: BigInt.from(1000000),
);

WalletUtxo _utxo({
  required int amountSat,
  int vout = 0,
  bool isFrozen = false,
}) => WalletUtxo.bitcoin(
  walletId: 'w-bitcoin',
  txId: 'a' * 64,
  vout: vout,
  scriptPubkey: Uint8List(0),
  amountSat: BigInt.from(amountSat),
  address: 'bc1-utxo',
  isFrozen: isFrozen,
);

FeeOptions _feeOptions() => const FeeOptions(
  fastest: RelativeFee(25),
  economic: RelativeFee(25),
  slow: RelativeFee(25),
  minRelay: RelativeFee(25),
);

const _sweepFeeOptions = FeeOptions(
  fastest: NetworkFee.relativeSatPerKwu(500),
  economic: NetworkFee.relativeSatPerKwu(250),
  slow: NetworkFee.relativeSatPerKwu(125),
  minRelay: RelativeFee(25),
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

PayjoinSenderSession _sender({
  required PayjoinStatus status,
  String? txId,
  String originalTxId = 'sender-orig-txid',
}) => PayjoinSenderSession(
  status: status,
  uri: 'bitcoin:bc1qaddr?amount=0.0005&pj=https://payjo.in',
  network: BitcoinNetwork.mainnet,
  walletId: 'w1',
  originalTransactionId: originalTxId,
  amount: Sats.fromInt(50000),
  createdAt: DateTime(2026),
  expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
  transactionId: txId,
);

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
  late _MockValidateBitcoinSelectionUsecase validateBitcoinSelectionUsecase;
  late _MockPrepareLiquidSendUsecase prepareLiquidSendUsecase;
  late _MockSendWithPayjoinUsecase sendWithPayjoinUsecase;
  late _MockWatchPayjoinUsecase watchPayjoinUsecase;
  late _MockPayjoinSessions payjoinSessions;
  late _MockGetWalletsUsecase getWalletsUsecase;
  late _MockGetWalletUsecase getWalletUsecase;
  late _MockCreateSendSwapUsecase createSendSwapUsecase;
  late _MockGetSendSwapQuoteUsecase getSendSwapQuoteUsecase;
  late _MockCreateSendCrossChainSwapUsecase createSendCrossChainSwapUsecase;
  late _MockGetSendCrossChainQuoteUsecase getSendCrossChainQuoteUsecase;
  late _MockResolveLightningAddressUsecase resolveLightningAddressUsecase;
  late _MockUpdateSendSwapPayinUsecase updateSendSwapPayinUsecase;
  late _MockWatchSendSwapUsecase watchSendSwapUsecase;
  late _MockUpdatePaidSendSwapUsecase updatePaidSendSwapUsecase;
  late _MockWatchFinishedWalletSyncsUsecase watchFinishedWalletSyncsUsecase;
  late _MockSignBitcoinTxUsecase signBitcoinTxUsecase;
  late _MockSignLiquidTxUsecase signLiquidTxUsecase;
  late _MockBroadcastBitcoinTransactionUsecase broadcastBitcoinTxUsecase;
  late _MockBroadcastLiquidTransactionUsecase broadcastLiquidTxUsecase;
  late _MockCalculateLiquidAbsoluteFeesUsecase
  calculateLiquidAbsoluteFeesUsecase;
  late _MockCalculateLiquidPsetSizeUsecase calculateLiquidPsetSizeUsecase;
  late _MockWatchWalletTransactionByTxIdUsecase
  watchWalletTransactionByTxIdUsecase;
  late _MockCalculateBitcoinAbsoluteFeesUsecase
  calculateBitcoinAbsoluteFeesUsecase;
  late _MockVerifyChainSwapAmountSendUsecase verifyChainSwapAmountSendUsecase;
  late _MockVerifyExchangePayinUsecase verifyExchangePayinUsecase;
  late _MockPreviewBitcoinFeeUsecase previewBitcoinFeeUsecase;
  late _MockPreviewBitcoinFeePresetsUsecase previewBitcoinFeePresetsUsecase;
  late _MockCheckLiquidConsolidationUsecase checkLiquidConsolidationUsecase;
  late _MockGetSendPayjoinEnabledUsecase getSendPayjoinEnabledUsecase;
  late _MockVerifySignedTxUsecase verifySignedTxUsecase;

  late StreamController<PayjoinSession> payjoinEvents;

  _TestableSendCubit buildCubit({
    Wallet? wallet,
    Set<Outpoint> initialSweepOutpoints = const {},
    Future<PaymentRequest> Function(String)? parsePaymentRequest,
  }) => _TestableSendCubit(
    wallet: wallet,
    initialSweepOutpoints: initialSweepOutpoints,
    labelsFacade: labelsFacade,
    bestWalletUsecase: bestWalletUsecase,
    detectBitcoinStringUsecase: detectBitcoinStringUsecase,
    getSettingsUsecase: getSettingsUsecase,
    convertSatsToCurrencyAmountUsecase: convertSatsUsecase,
    getNetworkFeesUsecase: getNetworkFeesUsecase,
    getWalletUtxosUsecase: getWalletUtxosUsecase,
    getAvailableCurrenciesUsecase: getAvailableCurrenciesUsecase,
    prepareBitcoinSendUsecase: prepareBitcoinSendUsecase,
    validateBitcoinSelectionUsecase: validateBitcoinSelectionUsecase,
    prepareLiquidSendUsecase: prepareLiquidSendUsecase,
    sendWithPayjoinUsecase: sendWithPayjoinUsecase,
    watchPayjoinUsecase: watchPayjoinUsecase,
    getWalletsUsecase: getWalletsUsecase,
    getWalletUsecase: getWalletUsecase,
    createSendSwapUsecase: createSendSwapUsecase,
    getSendSwapQuoteUsecase: getSendSwapQuoteUsecase,
    createSendCrossChainSwapUsecase: createSendCrossChainSwapUsecase,
    getSendCrossChainQuoteUsecase: getSendCrossChainQuoteUsecase,
    resolveLightningAddressUsecase: resolveLightningAddressUsecase,
    updateSendSwapPayinUsecase: updateSendSwapPayinUsecase,
    watchSendSwapUsecase: watchSendSwapUsecase,
    updatePaidSendSwapUsecase: updatePaidSendSwapUsecase,
    watchFinishedWalletSyncsUsecase: watchFinishedWalletSyncsUsecase,
    signBitcoinTxUsecase: signBitcoinTxUsecase,
    signLiquidTxUsecase: signLiquidTxUsecase,
    broadcastBitcoinTxUsecase: broadcastBitcoinTxUsecase,
    broadcastLiquidTxUsecase: broadcastLiquidTxUsecase,
    calculateLiquidAbsoluteFeesUsecase: calculateLiquidAbsoluteFeesUsecase,
    calculateLiquidPsetSizeUsecase: calculateLiquidPsetSizeUsecase,
    watchWalletTransactionByTxIdUsecase: watchWalletTransactionByTxIdUsecase,
    calculateBitcoinAbsoluteFeesUsecase: calculateBitcoinAbsoluteFeesUsecase,
    verifyChainSwapAmountSendUsecase: verifyChainSwapAmountSendUsecase,
    verifyExchangePayinUsecase: verifyExchangePayinUsecase,
    previewBitcoinFeeUsecase: previewBitcoinFeeUsecase,
    previewBitcoinFeePresetsUsecase: previewBitcoinFeePresetsUsecase,
    checkLiquidConsolidationUsecase: checkLiquidConsolidationUsecase,
    getSendPayjoinEnabledUsecase: getSendPayjoinEnabledUsecase,
    verifySignedTxUsecase: verifySignedTxUsecase,
    resolveSweepInputsUsecase: ResolveSweepInputsUsecase(payjoinSessions),
    validateSweepPaymentRequestUsecase: ValidateSweepPaymentRequestUsecase(),
    parsePaymentRequest: parsePaymentRequest,
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
    registerFallbackValue(_bitcoinLocalWallet());
    registerFallbackValue(BigInt.zero);
    registerFallbackValue(
      const PaymentRequest.bitcoin(address: 'fallback', isTestnet: true),
    );
    // For any(named: 'feeRate') on the prepare-send stubs.
    registerFallbackValue(NetworkFee.relativeFromSatPerVbyte(1));
    registerFallbackValue(<BitcoinTransactionRecipient>[]);
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
    validateBitcoinSelectionUsecase = _MockValidateBitcoinSelectionUsecase();
    when(
      () => validateBitcoinSelectionUsecase.execute(
        walletId: any(named: 'walletId'),
        selectedInputs: any(named: 'selectedInputs'),
      ),
    ).thenAnswer((_) async => []);
    prepareLiquidSendUsecase = _MockPrepareLiquidSendUsecase();
    sendWithPayjoinUsecase = _MockSendWithPayjoinUsecase();
    watchPayjoinUsecase = _MockWatchPayjoinUsecase();
    payjoinSessions = _MockPayjoinSessions();
    getWalletsUsecase = _MockGetWalletsUsecase();
    getWalletUsecase = _MockGetWalletUsecase();
    createSendSwapUsecase = _MockCreateSendSwapUsecase();
    getSendSwapQuoteUsecase = _MockGetSendSwapQuoteUsecase();
    createSendCrossChainSwapUsecase = _MockCreateSendCrossChainSwapUsecase();
    getSendCrossChainQuoteUsecase = _MockGetSendCrossChainQuoteUsecase();
    resolveLightningAddressUsecase = _MockResolveLightningAddressUsecase();
    updateSendSwapPayinUsecase = _MockUpdateSendSwapPayinUsecase();
    watchSendSwapUsecase = _MockWatchSendSwapUsecase();
    updatePaidSendSwapUsecase = _MockUpdatePaidSendSwapUsecase();
    watchFinishedWalletSyncsUsecase = _MockWatchFinishedWalletSyncsUsecase();
    signBitcoinTxUsecase = _MockSignBitcoinTxUsecase();
    signLiquidTxUsecase = _MockSignLiquidTxUsecase();
    broadcastBitcoinTxUsecase = _MockBroadcastBitcoinTransactionUsecase();
    broadcastLiquidTxUsecase = _MockBroadcastLiquidTransactionUsecase();
    calculateLiquidAbsoluteFeesUsecase =
        _MockCalculateLiquidAbsoluteFeesUsecase();
    calculateLiquidPsetSizeUsecase = _MockCalculateLiquidPsetSizeUsecase();
    watchWalletTransactionByTxIdUsecase =
        _MockWatchWalletTransactionByTxIdUsecase();
    calculateBitcoinAbsoluteFeesUsecase =
        _MockCalculateBitcoinAbsoluteFeesUsecase();
    verifyChainSwapAmountSendUsecase = _MockVerifyChainSwapAmountSendUsecase();
    verifyExchangePayinUsecase = _MockVerifyExchangePayinUsecase();
    previewBitcoinFeeUsecase = _MockPreviewBitcoinFeeUsecase();
    previewBitcoinFeePresetsUsecase = _MockPreviewBitcoinFeePresetsUsecase();
    checkLiquidConsolidationUsecase = _MockCheckLiquidConsolidationUsecase();
    getSendPayjoinEnabledUsecase = _MockGetSendPayjoinEnabledUsecase();
    verifySignedTxUsecase = _MockVerifySignedTxUsecase();
    // A hardware signer that returns what it was asked to sign: the default
    // is acceptance, tests that need a tampered device re-stub it.
    when(
      () => verifySignedTxUsecase.execute(
        unsignedPsbt: any(named: 'unsignedPsbt'),
        signedTransaction: any(named: 'signedTransaction'),
      ),
    ).thenAnswer((_) async => const Ok<void, SendFailure>(null));

    payjoinEvents = StreamController<PayjoinSession>.broadcast();

    // Benign default stubs for everything the payjoin branch (or its
    // aftermath) touches.
    when(() => watchPayjoinUsecase.execute(ids: any(named: 'ids'))).thenAnswer(
      (_) => payjoinEvents.stream.map(Ok<PayjoinSession, SendFailure>.new),
    );
    when(
      () => payjoinSessions.reservedOutpoints(),
    ).thenAnswer((_) async => const Ok(<Outpoint>{}));
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
    ).thenAnswer(
      (_) async => Ok<PayjoinSenderSession, SendFailure>(
        _sender(status: PayjoinStatus.requested),
      ),
    );

    cubit.setStateForTest(payjoinReadyState(label: label));
    await cubit.signTransaction();
    return cubit;
  }

  void stubSweepLoad({
    required Wallet wallet,
    required List<WalletUtxo> utxos,
  }) {
    when(() => getWalletsUsecase.execute()).thenAnswer((_) async => [wallet]);
    when(() => getSettingsUsecase.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    when(
      () => getSendPayjoinEnabledUsecase.execute(),
    ).thenAnswer((_) async => true);
    when(() => convertSatsUsecase.execute()).thenAnswer((_) async => 50000);
    when(
      () => convertSatsUsecase.execute(currencyCode: 'USD'),
    ).thenAnswer((_) async => 50000);
    when(
      () => getAvailableCurrenciesUsecase.execute(),
    ).thenAnswer((_) async => ['USD']);
    when(
      () => getWalletUtxosUsecase.execute(walletId: wallet.id),
    ).thenAnswer((_) async => utxos);
    when(
      () => watchFinishedWalletSyncsUsecase.execute(walletId: wallet.id),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => getNetworkFeesUsecase.execute(isLiquid: any(named: 'isLiquid')),
    ).thenAnswer((_) async => _sweepFeeOptions);
  }

  group('SendCubit selected-coin sweep', () {
    test('sets sweep intent before wallet loading completes', () async {
      final wallet = _bitcoinLocalWallet();
      final selected = walletUtxoFixture(
        walletId: wallet.id,
        txId: 'selected',
        sats: 75000,
      );
      stubSweepLoad(wallet: wallet, utxos: [selected]);
      final walletsCompleter = Completer<List<Wallet>>();
      when(
        () => getWalletsUsecase.execute(),
      ).thenAnswer((_) => walletsCompleter.future);
      final cubit = buildCubit(
        wallet: wallet,
        initialSweepOutpoints: const {(txId: 'selected', vout: 0)},
      );
      addTearDown(cubit.close);

      final load = cubit.loadWalletWithRatesAndFees();

      expect(cubit.state.isSweep, isTrue);
      expect(cubit.state.sweepDestinationBlocked, isTrue);
      await cubit.onScannedPaymentRequest(
        'bitcoin:bc1qrecipient?amount=0.0005',
        const PaymentRequest.bip21(
          network: Network.bitcoinMainnet,
          uri: 'bitcoin:bc1qrecipient?amount=0.0005',
          address: 'bc1qrecipient',
          amountSat: 50000,
        ),
      );
      expect(cubit.state.paymentRequest, isNull);
      verifyNever(
        () => prepareBitcoinSendUsecase.execute(
          walletId: any(named: 'walletId'),
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          replaceByFee: any(named: 'replaceByFee'),
          selectedInputs: any(named: 'selectedInputs'),
          selectedOnly: any(named: 'selectedOnly'),
        ),
      );

      walletsCompleter.complete([wallet]);
      await load;
      expect(cubit.state.sweepDestinationBlocked, isFalse);
      expect(cubit.state.selectedUtxos, [selected]);
    });

    test('initializes with exactly the requested spendable coins', () async {
      final wallet = _bitcoinLocalWallet();
      final selected = walletUtxoFixture(
        walletId: wallet.id,
        txId: 'selected',
        sats: 75000,
      );
      final other = walletUtxoFixture(
        walletId: wallet.id,
        txId: 'other',
        sats: 225000,
      );
      stubSweepLoad(wallet: wallet, utxos: [selected, other]);
      final cubit = buildCubit(
        wallet: wallet,
        initialSweepOutpoints: const {(txId: 'selected', vout: 0)},
      );
      addTearDown(cubit.close);

      await cubit.loadWalletWithRatesAndFees();

      expect(cubit.state.isSweep, isTrue);
      expect(cubit.state.selectedUtxos, [selected]);
      expect(cubit.state.spendableBalanceSat, 75000);
      expect(cubit.state.amount, '75000');
      expect(cubit.state.willAttemptPayjoin, isFalse);
      expect(cubit.state.failure, isNull);
    });

    test('keeps the selected-input wallet fixed', () async {
      final wallet = _bitcoinLocalWallet();
      final otherWallet = _bitcoinWallet(balanceSat: 500000);
      final selected = walletUtxoFixture(
        walletId: wallet.id,
        txId: 'selected',
        sats: 75000,
      );
      stubSweepLoad(wallet: wallet, utxos: [selected]);
      final cubit = buildCubit(
        wallet: wallet,
        initialSweepOutpoints: const {(txId: 'selected', vout: 0)},
      );
      addTearDown(cubit.close);
      await cubit.loadWalletWithRatesAndFees();
      cubit.setStateForTest(
        cubit.state.copyWith(wallets: [wallet, otherWallet]),
      );

      await cubit.updateSelectedWallet(otherWallet);

      expect(cubit.state.selectedWallet, wallet);
      expect(cubit.state.selectedUtxos, [selected]);
      expect(cubit.state.selectableWallets, [wallet]);
    });

    test('reports unavailable when a requested coin is missing', () async {
      final wallet = _bitcoinLocalWallet();
      stubSweepLoad(wallet: wallet, utxos: const []);
      final cubit = buildCubit(
        wallet: wallet,
        initialSweepOutpoints: const {(txId: 'missing', vout: 1)},
      );
      addTearDown(cubit.close);

      await cubit.loadWalletWithRatesAndFees();

      expect(cubit.state.selectedUtxos, isEmpty);
      expect(cubit.state.failure, isA<SendSelectedCoinsUnavailableFailure>());
    });

    test('rejects a BIP21 request that specifies an amount', () async {
      final wallet = _bitcoinLocalWallet();
      final selected = walletUtxoFixture(
        walletId: wallet.id,
        txId: 'selected',
        sats: 75000,
      );
      stubSweepLoad(wallet: wallet, utxos: [selected]);
      final cubit = buildCubit(
        wallet: wallet,
        initialSweepOutpoints: const {(txId: 'selected', vout: 0)},
      );
      addTearDown(cubit.close);
      await cubit.loadWalletWithRatesAndFees();

      await cubit.onScannedPaymentRequest(
        'bitcoin:bc1qrecipient?amount=0.0005',
        const PaymentRequest.bip21(
          network: Network.bitcoinMainnet,
          uri: 'bitcoin:bc1qrecipient?amount=0.0005',
          address: 'bc1qrecipient',
          amountSat: 50000,
        ),
      );

      expect(cubit.state.step, SendStep.address);
      expect(cubit.state.failure, isA<SendInvalidPaymentRequestFailure>());
      verifyNever(
        () => prepareBitcoinSendUsecase.execute(
          walletId: any(named: 'walletId'),
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          replaceByFee: any(named: 'replaceByFee'),
          selectedInputs: any(named: 'selectedInputs'),
          selectedOnly: any(named: 'selectedOnly'),
        ),
      );
    });

    test('preserves the label from an amountless BIP21 request', () async {
      final wallet = _bitcoinLocalWallet();
      final selected = walletUtxoFixture(
        walletId: wallet.id,
        txId: 'selected',
        sats: 75000,
      );
      stubSweepLoad(wallet: wallet, utxos: [selected]);
      when(
        () => prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          replaceByFee: true,
          selectedInputs: any(named: 'selectedInputs'),
          selectedOnly: true,
        ),
      ).thenAnswer(
        (_) async => (
          unsignedPsbt: 'unsigned',
          txSize: 110,
          isToSelf: false,
          recipientAmountsSat: [Sats.fromInt(74000)],
        ),
      );
      when(
        () =>
            signBitcoinTxUsecase.execute(psbt: 'unsigned', walletId: wallet.id),
      ).thenAnswer((_) async => (signedPsbt: 'signed', txSize: 110));
      when(
        () => calculateBitcoinAbsoluteFeesUsecase.execute(
          psbt: any(named: 'psbt'),
        ),
      ).thenAnswer((_) async => 1000);
      final cubit = buildCubit(
        wallet: wallet,
        initialSweepOutpoints: const {(txId: 'selected', vout: 0)},
      );
      addTearDown(cubit.close);
      await cubit.loadWalletWithRatesAndFees();

      await cubit.onScannedPaymentRequest(
        'bitcoin:bc1qrecipient?label=rent',
        const PaymentRequest.bip21(
          network: Network.bitcoinMainnet,
          uri: 'bitcoin:bc1qrecipient?label=rent',
          address: 'bc1qrecipient',
          label: 'rent',
        ),
      );

      expect(cubit.state.label, 'rent');
      expect(cubit.state.step, SendStep.confirm);
    });

    test(
      'reports unavailable when a selected input is reserved during build',
      () async {
        final wallet = _bitcoinLocalWallet();
        final selected = walletUtxoFixture(
          walletId: wallet.id,
          txId: 'selected',
          sats: 75000,
        );
        stubSweepLoad(wallet: wallet, utxos: [selected]);
        when(
          () => prepareBitcoinSendUsecase.execute(
            walletId: wallet.id,
            recipients: any(named: 'recipients'),
            networkFee: any(named: 'networkFee'),
            replaceByFee: true,
            selectedInputs: any(named: 'selectedInputs'),
            selectedOnly: true,
          ),
        ).thenThrow(
          SelectedInputsUnavailableException('selected input is reserved'),
        );
        final cubit = buildCubit(
          wallet: wallet,
          initialSweepOutpoints: const {(txId: 'selected', vout: 0)},
        );
        addTearDown(cubit.close);
        await cubit.loadWalletWithRatesAndFees();

        cubit.setStateForTest(
          cubit.state.copyWith(
            paymentRequest: const PaymentRequest.bitcoin(
              address: 'bc1qrecipient',
              isTestnet: false,
            ),
            confirmedAmountSat: 75000,
            unsignedPsbt: 'stale-unsigned',
            signedBitcoinPsbt: 'stale-psbt',
            signedBitcoinTx: 'stale-tx',
          ),
        );

        await cubit.createTransaction();

        expect(cubit.state.failure, isA<SendSelectedCoinsUnavailableFailure>());
        expect(cubit.state.unsignedPsbt, isNull);
        expect(cubit.state.signedBitcoinPsbt, isNull);
        expect(cubit.state.signedBitcoinTx, isNull);
      },
    );

    test(
      'failed RBF rebuild clears the previously signed transaction',
      () async {
        final wallet = _bitcoinLocalWallet();
        final selected = walletUtxoFixture(
          walletId: wallet.id,
          txId: 'selected',
          sats: 75000,
        );
        stubSweepLoad(wallet: wallet, utxos: [selected]);
        when(
          () => prepareBitcoinSendUsecase.execute(
            walletId: wallet.id,
            recipients: any(named: 'recipients'),
            networkFee: any(named: 'networkFee'),
            replaceByFee: false,
            selectedInputs: any(named: 'selectedInputs'),
            selectedOnly: true,
          ),
        ).thenThrow(
          InsufficientFundsException('selected input cannot cover fee'),
        );
        final cubit = buildCubit(
          wallet: wallet,
          initialSweepOutpoints: const {(txId: 'selected', vout: 0)},
        );
        addTearDown(cubit.close);
        await cubit.loadWalletWithRatesAndFees();
        cubit.setStateForTest(
          cubit.state.copyWith(
            step: SendStep.confirm,
            paymentRequest: const PaymentRequest.bitcoin(
              address: 'bc1qrecipient',
              isTestnet: false,
            ),
            confirmedAmountSat: 74000,
            unsignedPsbt: 'old-unsigned',
            signedBitcoinPsbt: 'old-signed',
          ),
        );

        await cubit.replaceByFeeChanged(false);

        expect(
          cubit.state.failure,
          isA<SendSelectedCoinsInsufficientFailure>(),
        );
        expect(cubit.state.unsignedPsbt, isNull);
        expect(cubit.state.signedBitcoinPsbt, isNull);
      },
    );

    test('ignores an older sweep build after a newer rebuild fails', () async {
      final wallet = _bitcoinLocalWallet();
      final selected = walletUtxoFixture(
        walletId: wallet.id,
        txId: 'selected',
        sats: 75000,
      );
      stubSweepLoad(wallet: wallet, utxos: [selected]);
      final olderBuildStarted = Completer<void>();
      final olderBuildResult =
          Completer<
            ({
              String unsignedPsbt,
              int txSize,
              bool isToSelf,
              List<Sats> recipientAmountsSat,
            })
          >();
      when(
        () => prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          replaceByFee: true,
          selectedInputs: any(named: 'selectedInputs'),
          selectedOnly: true,
        ),
      ).thenAnswer((_) {
        olderBuildStarted.complete();
        return olderBuildResult.future;
      });
      when(
        () => prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          replaceByFee: false,
          selectedInputs: any(named: 'selectedInputs'),
          selectedOnly: true,
        ),
      ).thenThrow(
        InsufficientFundsException('selected input cannot cover fee'),
      );
      when(
        () => calculateBitcoinAbsoluteFeesUsecase.execute(
          psbt: any(named: 'psbt'),
        ),
      ).thenAnswer((_) async => 1000);
      when(
        () => signBitcoinTxUsecase.execute(
          psbt: any(named: 'psbt'),
          walletId: wallet.id,
        ),
      ).thenAnswer((_) async => (signedPsbt: 'older-signed', txSize: 110));
      final cubit = buildCubit(
        wallet: wallet,
        initialSweepOutpoints: const {(txId: 'selected', vout: 0)},
      );
      addTearDown(cubit.close);
      await cubit.loadWalletWithRatesAndFees();
      cubit.setStateForTest(
        cubit.state.copyWith(
          step: SendStep.confirm,
          paymentRequest: const PaymentRequest.bitcoin(
            address: 'bc1qrecipient',
            isTestnet: false,
          ),
          confirmedAmountSat: 74000,
        ),
      );

      final olderBuild = cubit.createTransaction();
      await olderBuildStarted.future;
      await cubit.replaceByFeeChanged(false);
      olderBuildResult.complete((
        unsignedPsbt: 'older-unsigned',
        txSize: 110,
        isToSelf: false,
        recipientAmountsSat: [Sats.fromInt(74000)],
      ));
      await olderBuild;

      expect(cubit.state.replaceByFee, isFalse);
      expect(cubit.state.failure, isA<SendSelectedCoinsInsufficientFailure>());
      expect(cubit.state.unsignedPsbt, isNull);
      expect(cubit.state.signedBitcoinPsbt, isNull);
      verifyNever(
        () => signBitcoinTxUsecase.execute(
          psbt: any(named: 'psbt'),
          walletId: wallet.id,
        ),
      );
    });

    test('revalidates selected coins before broadcasting', () async {
      final wallet = _bitcoinLocalWallet();
      final selected = walletUtxoFixture(
        walletId: wallet.id,
        txId: 'selected',
        sats: 75000,
      );
      stubSweepLoad(wallet: wallet, utxos: [selected]);
      final cubit = buildCubit(
        wallet: wallet,
        initialSweepOutpoints: const {(txId: 'selected', vout: 0)},
      );
      addTearDown(cubit.close);
      await cubit.loadWalletWithRatesAndFees();
      cubit.setStateForTest(
        cubit.state.copyWith(
          step: SendStep.confirm,
          paymentRequest: const PaymentRequest.bitcoin(
            address: 'bc1qrecipient',
            isTestnet: false,
          ),
          confirmedAmountSat: 74000,
          unsignedPsbt: 'unsigned',
          signedBitcoinPsbt: 'signed',
        ),
      );
      when(
        () => getWalletUtxosUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) async => const []);

      await cubit.onConfirmTransactionClicked();

      expect(cubit.state.failure, isA<SendSelectedCoinsUnavailableFailure>());
      expect(cubit.state.unsignedPsbt, isNull);
      expect(cubit.state.signedBitcoinPsbt, isNull);
      expect(cubit.state.signedBitcoinTx, isNull);
      verifyNever(
        () => broadcastBitcoinTxUsecase.execute(
          any(),
          isPsbt: any(named: 'isPsbt'),
        ),
      );
    });

    test('rejects a newly Payjoin-reserved coin before broadcasting', () async {
      final wallet = _bitcoinLocalWallet();
      final selected = walletUtxoFixture(
        walletId: wallet.id,
        txId: 'selected',
        sats: 75000,
      );
      stubSweepLoad(wallet: wallet, utxos: [selected]);
      final cubit = buildCubit(
        wallet: wallet,
        initialSweepOutpoints: const {(txId: 'selected', vout: 0)},
      );
      addTearDown(cubit.close);
      await cubit.loadWalletWithRatesAndFees();
      cubit.setStateForTest(
        cubit.state.copyWith(
          step: SendStep.confirm,
          paymentRequest: const PaymentRequest.bitcoin(
            address: 'bc1qrecipient',
            isTestnet: false,
          ),
          confirmedAmountSat: 74000,
          unsignedPsbt: 'unsigned',
          signedBitcoinPsbt: 'signed',
        ),
      );
      when(() => payjoinSessions.reservedOutpoints()).thenAnswer(
        (_) async => const Ok(<Outpoint>{(txId: 'selected', vout: 0)}),
      );

      await cubit.onConfirmTransactionClicked();

      expect(cubit.state.failure, isA<SendSelectedCoinsUnavailableFailure>());
      expect(cubit.state.unsignedPsbt, isNull);
      expect(cubit.state.signedBitcoinPsbt, isNull);
      verifyNever(
        () => broadcastBitcoinTxUsecase.execute(
          any(),
          isPsbt: any(named: 'isPsbt'),
        ),
      );
    });

    test('drains only the selected coins and signs locally', () async {
      final wallet = _bitcoinLocalWallet();
      final selected = walletUtxoFixture(
        walletId: wallet.id,
        txId: 'selected',
        sats: 75000,
      );
      final other = walletUtxoFixture(
        walletId: wallet.id,
        txId: 'other',
        sats: 225000,
      );
      stubSweepLoad(wallet: wallet, utxos: [selected, other]);
      when(
        () => prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          replaceByFee: true,
          selectedInputs: any(named: 'selectedInputs'),
          selectedOnly: true,
        ),
      ).thenAnswer(
        (_) async => (
          unsignedPsbt: 'unsigned',
          txSize: 110,
          isToSelf: false,
          recipientAmountsSat: [Sats.fromInt(74000)],
        ),
      );
      when(
        () =>
            signBitcoinTxUsecase.execute(psbt: 'unsigned', walletId: wallet.id),
      ).thenAnswer((_) async => (signedPsbt: 'signed', txSize: 110));
      when(
        () => calculateBitcoinAbsoluteFeesUsecase.execute(
          psbt: any(named: 'psbt'),
        ),
      ).thenAnswer((_) async => 1000);
      final cubit = buildCubit(
        wallet: wallet,
        initialSweepOutpoints: const {(txId: 'selected', vout: 0)},
      );
      addTearDown(cubit.close);
      await cubit.loadWalletWithRatesAndFees();

      await cubit.onScannedPaymentRequest(
        'bc1qrecipient',
        const PaymentRequest.bitcoin(
          address: 'bc1qrecipient',
          isTestnet: false,
        ),
      );

      final captured = verify(
        () => prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          recipients: captureAny(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          replaceByFee: true,
          selectedInputs: captureAny(named: 'selectedInputs'),
          selectedOnly: true,
        ),
      ).captured;
      final recipients = captured[0] as List<BitcoinTransactionRecipient>;
      final selectedInputs = captured[1] as List<WalletUtxo>;
      expect(recipients.single.address, 'bc1qrecipient');
      expect(recipients.single.receivesRemainder, isTrue);
      expect(selectedInputs, [selected]);
      verify(
        () =>
            signBitcoinTxUsecase.execute(psbt: 'unsigned', walletId: wallet.id),
      ).called(1);
      expect(cubit.state.step, SendStep.confirm);
      expect(cubit.state.confirmedAmountSat, 74000);
      expect(cubit.state.signedBitcoinPsbt, 'signed');
    });

    test(
      'builds fixed and remainder outputs from exactly selected coins',
      () async {
        final wallet = _bitcoinLocalWallet();
        final selected = walletUtxoFixture(
          walletId: wallet.id,
          txId: 'selected',
          sats: 75000,
        );
        stubSweepLoad(wallet: wallet, utxos: [selected]);
        when(
          () => prepareBitcoinSendUsecase.execute(
            walletId: wallet.id,
            recipients: any(named: 'recipients'),
            networkFee: any(named: 'networkFee'),
            replaceByFee: true,
            selectedInputs: any(named: 'selectedInputs'),
            selectedOnly: true,
          ),
        ).thenAnswer(
          (_) async => (
            unsignedPsbt: 'unsigned-multi-sweep',
            txSize: 140,
            isToSelf: false,
            recipientAmountsSat: [Sats.fromInt(10000), Sats.fromInt(64000)],
          ),
        );
        when(
          () => signBitcoinTxUsecase.execute(
            psbt: 'unsigned-multi-sweep',
            walletId: wallet.id,
          ),
        ).thenAnswer((_) async => (signedPsbt: 'signed', txSize: 140));
        when(
          () => calculateBitcoinAbsoluteFeesUsecase.execute(
            psbt: any(named: 'psbt'),
          ),
        ).thenAnswer((_) async => 1000);
        final cubit = buildCubit(
          wallet: wallet,
          initialSweepOutpoints: const {(txId: 'selected', vout: 0)},
        );
        addTearDown(cubit.close);
        await cubit.loadWalletWithRatesAndFees();
        cubit.setStateForTest(
          cubit.state.copyWith(
            paymentRequest: const PaymentRequest.bitcoin(
              address: 'bc1qfixed',
              isTestnet: false,
            ),
            step: SendStep.amount,
            recipientDrafts: const [
              (
                id: 0,
                address: 'bc1qfixed',
                amount: '10000',
                receivesRemainder: false,
                isValid: true,
              ),
              (
                id: 1,
                address: 'bc1qremaining',
                amount: '',
                receivesRemainder: true,
                isValid: true,
              ),
            ],
          ),
        );

        await cubit.createTransaction();

        final captured = verify(
          () => prepareBitcoinSendUsecase.execute(
            walletId: wallet.id,
            recipients: captureAny(named: 'recipients'),
            networkFee: any(named: 'networkFee'),
            replaceByFee: true,
            selectedInputs: captureAny(named: 'selectedInputs'),
            selectedOnly: true,
          ),
        ).captured;
        final recipients = captured[0] as List<BitcoinTransactionRecipient>;
        final selectedInputs = captured[1] as List<WalletUtxo>;
        expect(recipients.map((recipient) => recipient.amountSat), [
          Sats.fromInt(10000),
          null,
        ]);
        expect(selectedInputs, [selected]);
        expect(cubit.state.recipientAmountsSat, [10000, 64000]);
        expect(cubit.state.signedBitcoinPsbt, 'signed');
      },
    );

    test(
      'transfers the sweep remainder without copying the sweep total',
      () async {
        final wallet = _bitcoinLocalWallet();
        final selected = walletUtxoFixture(
          walletId: wallet.id,
          txId: 'selected',
          sats: 75000,
        );
        stubSweepLoad(wallet: wallet, utxos: [selected]);
        when(
          () => detectBitcoinStringUsecase.execute(data: 'bc1qfirst'),
        ).thenAnswer(
          (_) async => const PaymentRequest.bitcoin(
            address: 'bc1qfirst',
            isTestnet: false,
          ),
        );
        when(
          () => detectBitcoinStringUsecase.execute(data: 'bc1qsecond'),
        ).thenAnswer(
          (_) async => const PaymentRequest.bitcoin(
            address: 'bc1qsecond',
            isTestnet: false,
          ),
        );
        final cubit = buildCubit(
          wallet: wallet,
          initialSweepOutpoints: const {(txId: 'selected', vout: 0)},
        );
        addTearDown(cubit.close);

        await cubit.loadWalletWithRatesAndFees();
        cubit.onChangedText('bc1qfirst');
        expect(await cubit.addRecipient(), isTrue);
        await cubit.recipientAddressChanged(1, 'bc1qsecond');

        expect(cubit.state.amount, '75000');
        expect(cubit.state.recipientDrafts.first.amount, isEmpty);

        cubit.setRemainderRecipient(1, true);

        expect(cubit.state.recipientDrafts.first.amount, isEmpty);
        expect(cubit.state.recipientDrafts.first.receivesRemainder, isFalse);
        expect(cubit.state.recipientDrafts[1].receivesRemainder, isTrue);
      },
    );

    test('leaves watch-only drains unsigned for PSBT export', () async {
      final wallet = _bitcoinWatchOnlyWallet();
      final selected = walletUtxoFixture(
        walletId: wallet.id,
        txId: 'selected',
        sats: 75000,
      );
      stubSweepLoad(wallet: wallet, utxos: [selected]);
      when(
        () => prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          replaceByFee: true,
          selectedInputs: any(named: 'selectedInputs'),
          selectedOnly: true,
        ),
      ).thenAnswer(
        (_) async => (
          unsignedPsbt: 'unsigned',
          txSize: 110,
          isToSelf: false,
          recipientAmountsSat: [Sats.fromInt(74000)],
        ),
      );
      when(
        () => calculateBitcoinAbsoluteFeesUsecase.execute(psbt: 'unsigned'),
      ).thenAnswer((_) async => 1000);
      final cubit = buildCubit(
        wallet: wallet,
        initialSweepOutpoints: const {(txId: 'selected', vout: 0)},
      );
      addTearDown(cubit.close);
      await cubit.loadWalletWithRatesAndFees();

      await cubit.onScannedPaymentRequest(
        'bc1qrecipient',
        const PaymentRequest.bitcoin(
          address: 'bc1qrecipient',
          isTestnet: false,
        ),
      );

      verifyNever(
        () => signBitcoinTxUsecase.execute(
          psbt: any(named: 'psbt'),
          walletId: any(named: 'walletId'),
        ),
      );
      expect(cubit.state.step, SendStep.confirm);
      expect(cubit.state.unsignedPsbt, 'unsigned');
      expect(cubit.state.signedBitcoinPsbt, isNull);
    });
  });

  group('SendCubit multi-recipient sends', () {
    SendState readyState(Wallet wallet) => SendState(
      sendType: SendType.bitcoin,
      selectedWallet: wallet,
      paymentRequest: const PaymentRequest.bitcoin(
        address: 'bc1qfirst',
        isTestnet: false,
      ),
      bitcoinUnit: BitcoinUnit.sats,
      inputAmountCurrencyCode: BitcoinUnit.sats.code,
      bitcoinFeesList: _sweepFeeOptions,
      liquidFeesList: _sweepFeeOptions,
      recipientDrafts: const [
        (
          id: 0,
          address: 'bc1qfirst',
          amount: '10000',
          receivesRemainder: false,
          isValid: true,
        ),
        (
          id: 1,
          address: 'bc1qsecond',
          amount: '20000',
          receivesRemainder: false,
          isValid: true,
        ),
      ],
      confirmedAmountSat: 30000,
    );

    test('returns from multi-recipient sweep confirmation to amounts', () {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        readyState(_bitcoinLocalWallet()).copyWith(
          step: SendStep.confirm,
          sweepOutpoints: const {(txId: 'selected', vout: 0)},
        ),
      );

      cubit.backClicked();

      expect(cubit.state.step, SendStep.amount);
    });

    void stubMultiRecipientBuild(Wallet wallet) {
      when(
        () => getWalletUtxosUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) async => const []);
      when(
        () => prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          replaceByFee: true,
          selectedInputs: any(named: 'selectedInputs'),
          selectedOnly: false,
        ),
      ).thenAnswer(
        (_) async => (
          unsignedPsbt: 'unsigned',
          txSize: 140,
          isToSelf: false,
          recipientAmountsSat: [Sats.fromInt(10000), Sats.fromInt(20000)],
        ),
      );
      when(
        () => calculateBitcoinAbsoluteFeesUsecase.execute(
          psbt: any(named: 'psbt'),
        ),
      ).thenAnswer((_) async => 100);
    }

    test(
      'builds added recipients after leaving an earlier chain swap',
      () async {
        final wallet = _bitcoinLocalWallet();
        final staleSwap = _MockChainSwap();
        when(() => staleSwap.paymentAddress).thenReturn('bc1qstaleswap');
        when(() => staleSwap.paymentAmount).thenReturn(50000);
        stubMultiRecipientBuild(wallet);
        when(
          () => signBitcoinTxUsecase.execute(
            psbt: 'unsigned',
            walletId: wallet.id,
          ),
        ).thenAnswer((_) async => (signedPsbt: 'signed', txSize: 140));
        when(
          () => verifyChainSwapAmountSendUsecase.execute(
            psbtOrPset: any(named: 'psbtOrPset'),
            swap: staleSwap,
            walletId: any(named: 'walletId'),
          ),
        ).thenAnswer((_) async {});
        final cubit = buildCubit();
        addTearDown(cubit.close);
        cubit.setStateForTest(
          readyState(wallet).copyWith(
            step: SendStep.confirm,
            chainSwap: staleSwap,
            recipientDrafts: const [
              (
                id: 0,
                address: 'bc1qfirst',
                amount: '10000',
                receivesRemainder: false,
                isValid: true,
              ),
            ],
            recipientAmountsSat: const [10000],
          ),
        );

        cubit.backClicked();
        expect(await cubit.addRecipient(), isTrue);
        cubit.setStateForTest(
          cubit.state.copyWith(
            recipientDrafts: const [
              (
                id: 0,
                address: 'bc1qfirst',
                amount: '10000',
                receivesRemainder: false,
                isValid: true,
              ),
              (
                id: 1,
                address: 'bc1qsecond',
                amount: '20000',
                receivesRemainder: false,
                isValid: true,
              ),
            ],
          ),
        );

        expect(await cubit.createTransaction(), isTrue);

        final recipients =
            verify(
                  () => prepareBitcoinSendUsecase.execute(
                    walletId: wallet.id,
                    recipients: captureAny(named: 'recipients'),
                    networkFee: any(named: 'networkFee'),
                    replaceByFee: true,
                    selectedInputs: any(named: 'selectedInputs'),
                    selectedOnly: false,
                  ),
                ).captured.single
                as List<BitcoinTransactionRecipient>;
        expect(recipients.map((recipient) => recipient.address), [
          'bc1qfirst',
          'bc1qsecond',
        ]);
        expect(cubit.state.chainSwap, isNull);
        verifyNever(
          () => verifyChainSwapAmountSendUsecase.execute(
            psbtOrPset: any(named: 'psbtOrPset'),
            swap: staleSwap,
            walletId: any(named: 'walletId'),
          ),
        );
      },
    );

    test('stops an earlier order watcher when adding a recipient', () async {
      final wallet = _bitcoinLocalWallet();
      final quote = _MockOrderSwapQuote();
      final activeOrder = _MockOrderSwapRecord();
      final staleUpdate = _MockOrderSwapRecord();
      const invoice = PaymentRequest.bolt11(
        invoice: 'lnbc1-invoice',
        amountSat: 50000,
        paymentHash: 'hash',
        expiresAt: 2000000000,
        isTestnet: false,
      );
      final orderEvents =
          StreamController<Result<OrderSwapRecord, SendFailure>>.broadcast();
      addTearDown(orderEvents.close);
      when(() => quote.inAmountSat).thenReturn(BigInt.from(50100));
      when(() => activeOrder.localId).thenReturn('order-1');
      when(() => activeOrder.localPayinTransactionId).thenReturn(null);
      when(
        () => activeOrder.localStatus,
      ).thenReturn(OrderSwapLocalStatus.payoutInProgress);
      when(() => activeOrder.order).thenReturn(null);
      when(
        () => staleUpdate.localStatus,
      ).thenReturn(OrderSwapLocalStatus.payoutInProgress);
      when(
        () => getSendSwapQuoteUsecase.execute(
          wallet: wallet,
          amountSat: BigInt.from(50000),
        ),
      ).thenAnswer((_) async => Ok(quote));
      when(
        () => createSendSwapUsecase.execute(
          walletId: wallet.id,
          invoice: invoice as Bolt11PaymentRequest,
          amountSat: 50000,
          quote: quote,
          note: '',
        ),
      ).thenAnswer((_) async => Ok(activeOrder));
      when(
        () => watchSendSwapUsecase.execute('order-1'),
      ).thenAnswer((_) => orderEvents.stream);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        SendState(
          step: SendStep.confirm,
          sendType: SendType.lightning,
          selectedWallet: wallet,
          paymentRequest: invoice,
          amount: '50000',
          inputAmountCurrencyCode: BitcoinUnit.sats.code,
        ),
      );

      await cubit.onAmountConfirmed();
      expect(orderEvents.hasListener, isTrue);
      expect(cubit.state.lightningOrder, activeOrder);

      cubit.setStateForTest(
        readyState(wallet).copyWith(lightningOrder: activeOrder),
      );
      expect(await cubit.addRecipient(), isTrue);
      expect(orderEvents.hasListener, isFalse);
      expect(cubit.state.lightningOrder, isNull);

      orderEvents.add(Ok(staleUpdate));
      await pumpEventQueue();

      expect(cubit.state.lightningOrder, isNull);
    });

    test('ignores an address result after the cubit closes', () async {
      final detected = Completer<PaymentRequest>();
      when(
        () => detectBitcoinStringUsecase.execute(data: 'bc1qsecond'),
      ).thenAnswer((_) => detected.future);
      final cubit = buildCubit();
      cubit.setStateForTest(readyState(_bitcoinLocalWallet()));

      final update = cubit.recipientAddressChanged(1, 'bc1qsecond');
      await pumpEventQueue();
      await cubit.close();
      detected.complete(
        const PaymentRequest.bitcoin(address: 'bc1qsecond', isTestnet: false),
      );

      await expectLater(update, completes);
    });

    test('selecting a remainder recipient transfers the designation', () {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        readyState(_bitcoinLocalWallet()).copyWith(
          recipientDrafts: const [
            (
              id: 0,
              address: 'bc1qfirst',
              amount: '10000',
              receivesRemainder: true,
              isValid: true,
            ),
            (
              id: 1,
              address: 'bc1qsecond',
              amount: '20000',
              receivesRemainder: false,
              isValid: true,
            ),
          ],
        ),
      );

      cubit.setRemainderRecipient(1, true);

      expect(
        cubit.state.recipientDrafts
            .where((recipient) => recipient.receivesRemainder)
            .map((recipient) => recipient.id),
        [1],
      );
    });

    test('removing the remainder recipient clears max state', () {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        readyState(_bitcoinLocalWallet()).copyWith(
          recipientDrafts: const [
            (
              id: 0,
              address: 'bc1qfirst',
              amount: '10000',
              receivesRemainder: false,
              isValid: true,
            ),
            (
              id: 1,
              address: 'bc1qsecond',
              amount: '',
              receivesRemainder: true,
              isValid: true,
            ),
          ],
        ),
      );

      cubit.removeRecipient(1);

      expect(cubit.state.recipientDrafts, hasLength(1));
      expect(cubit.state.hasRemainderRecipient, isFalse);
      expect(cubit.state.isMaxSend, isFalse);
    });

    test('changing currency keeps the multi-recipient remainder', () async {
      when(
        () => convertSatsUsecase.execute(currencyCode: 'USD'),
      ).thenAnswer((_) async => 50000);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        readyState(_bitcoinLocalWallet()).copyWith(
          recipientDrafts: const [
            (
              id: 0,
              address: 'bc1qfirst',
              amount: '10000',
              receivesRemainder: false,
              isValid: true,
            ),
            (
              id: 1,
              address: 'bc1qsecond',
              amount: '',
              receivesRemainder: true,
              isValid: true,
            ),
          ],
        ),
      );

      await cubit.onCurrencyChanged('USD');

      expect(cubit.state.hasRemainderRecipient, isTrue);
      expect(cubit.state.isMaxSend, isTrue);
      expect(cubit.state.recipientDrafts.first.amount, isEmpty);
    });

    test(
      'prefills an amount-bearing BIP21 for an additional recipient',
      () async {
        const uri = 'bitcoin:bc1qsecond?amount=0.0005';
        when(() => detectBitcoinStringUsecase.execute(data: uri)).thenAnswer(
          (_) async => const PaymentRequest.bip21(
            network: Network.bitcoinMainnet,
            uri: uri,
            address: 'bc1qsecond',
            amountSat: 50000,
          ),
        );
        final cubit = buildCubit();
        addTearDown(cubit.close);
        cubit.setStateForTest(
          readyState(_bitcoinLocalWallet()).copyWith(
            recipientDrafts: const [
              (
                id: 0,
                address: 'bc1qfirst',
                amount: '10000',
                receivesRemainder: false,
                isValid: true,
              ),
              (
                id: 1,
                address: 'bc1qsecond',
                amount: '',
                receivesRemainder: true,
                isValid: true,
              ),
            ],
          ),
        );

        await cubit.recipientAddressChanged(1, uri);

        expect(cubit.state.recipientDrafts[1], (
          id: 1,
          address: 'bc1qsecond',
          amount: '50000',
          receivesRemainder: false,
          isValid: true,
        ));
        expect(
          cubit.state.bitcoinTransactionRecipients.map(
            (recipient) => recipient.amountSat,
          ),
          [Sats.fromInt(10000), Sats.fromInt(50000)],
        );
      },
    );

    test(
      'preserves fixed amounts when an embedded amount replaces fiat input',
      () async {
        const uri = 'bitcoin:bc1qsecond?amount=0.0005';
        when(() => detectBitcoinStringUsecase.execute(data: uri)).thenAnswer(
          (_) async => const PaymentRequest.bip21(
            network: Network.bitcoinMainnet,
            uri: uri,
            address: 'bc1qsecond',
            amountSat: 50000,
          ),
        );
        final cubit = buildCubit();
        addTearDown(cubit.close);
        cubit.setStateForTest(
          readyState(_bitcoinLocalWallet()).copyWith(
            bitcoinUnit: BitcoinUnit.btc,
            inputAmountCurrencyCode: 'USD',
            exchangeRate: 50000,
            amount: '5.00',
            recipientDrafts: const [
              (
                id: 0,
                address: 'bc1qfirst',
                amount: '5.00',
                receivesRemainder: false,
                isValid: true,
              ),
              (
                id: 1,
                address: '',
                amount: '',
                receivesRemainder: true,
                isValid: false,
              ),
            ],
          ),
        );

        await cubit.recipientAddressChanged(1, uri);

        expect(cubit.state.inputAmountCurrencyCode, BitcoinUnit.btc.code);
        expect(cubit.state.amount, '0.00010000');
        expect(
          cubit.state.recipientDrafts.map((recipient) => recipient.amount),
          ['0.00010000', '0.00050000'],
        );
        expect(cubit.state.recipientDrafts[1].receivesRemainder, isFalse);
      },
    );

    test('rejects an amount-bearing BIP21 during a sweep', () async {
      const uri = 'bitcoin:bc1qsecond?amount=0.0005';
      when(() => detectBitcoinStringUsecase.execute(data: uri)).thenAnswer(
        (_) async => const PaymentRequest.bip21(
          network: Network.bitcoinMainnet,
          uri: uri,
          address: 'bc1qsecond',
          amountSat: 50000,
        ),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        readyState(_bitcoinLocalWallet()).copyWith(
          sweepOutpoints: const {(txId: 'selected', vout: 0)},
          recipientDrafts: const [
            (
              id: 0,
              address: 'bc1qfirst',
              amount: '',
              receivesRemainder: true,
              isValid: true,
            ),
            (
              id: 1,
              address: '',
              amount: '',
              receivesRemainder: false,
              isValid: false,
            ),
          ],
        ),
      );

      await cubit.recipientAddressChanged(1, uri);

      expect(cubit.state.recipientDrafts[1].address, uri);
      expect(cubit.state.recipientDrafts[1].amount, isEmpty);
      expect(cubit.state.recipientDrafts[1].isValid, isFalse);
    });

    test('rejects an additional recipient on another network', () async {
      when(
        () => detectBitcoinStringUsecase.execute(data: 'tb1qsecond'),
      ).thenAnswer(
        (_) async => const PaymentRequest.bitcoin(
          address: 'tb1qsecond',
          isTestnet: true,
        ),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(readyState(_bitcoinLocalWallet()));

      await cubit.recipientAddressChanged(1, 'tb1qsecond');

      expect(cubit.state.recipientDrafts[1].isValid, isFalse);
      await cubit.onAmountConfirmed();
      verifyNever(
        () => prepareBitcoinSendUsecase.execute(
          walletId: any(named: 'walletId'),
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          replaceByFee: any(named: 'replaceByFee'),
          selectedInputs: any(named: 'selectedInputs'),
          selectedOnly: any(named: 'selectedOnly'),
        ),
      );
    });

    test(
      'keeps a secondary remainder when the primary address changes',
      () async {
        when(
          () => detectBitcoinStringUsecase.execute(data: 'bc1qnewfirst'),
        ).thenAnswer(
          (_) async => const PaymentRequest.bitcoin(
            address: 'bc1qnewfirst',
            isTestnet: false,
          ),
        );
        final cubit = buildCubit();
        addTearDown(cubit.close);
        cubit.setStateForTest(
          readyState(_bitcoinLocalWallet()).copyWith(
            recipientDrafts: const [
              (
                id: 0,
                address: 'bc1qfirst',
                amount: '10000',
                receivesRemainder: false,
                isValid: true,
              ),
              (
                id: 1,
                address: 'bc1qsecond',
                amount: '',
                receivesRemainder: true,
                isValid: true,
              ),
            ],
          ),
        );

        cubit.onChangedText('bc1qnewfirst');

        expect(cubit.state.recipientDrafts.first.address, 'bc1qnewfirst');
        expect(cubit.state.recipientDrafts[1].receivesRemainder, isTrue);
        expect(cubit.state.sendMax, isFalse);
        expect(cubit.state.isMaxSend, isTrue);
      },
    );

    test(
      'keeps additional recipients while the primary address is incomplete',
      () async {
        when(
          () => detectBitcoinStringUsecase.execute(data: any(named: 'data')),
        ).thenAnswer((_) async => throw StateError('incomplete address'));
        final cubit = buildCubit();
        addTearDown(cubit.close);
        cubit.setStateForTest(
          readyState(_bitcoinLocalWallet()).copyWith(
            recipientDrafts: const [
              (
                id: 0,
                address: 'bc1qfirst',
                amount: '10000',
                receivesRemainder: false,
                isValid: true,
              ),
              (
                id: 1,
                address: 'bc1qsecond',
                amount: '',
                receivesRemainder: true,
                isValid: true,
              ),
            ],
            recipientAmountsSat: const [10000, 989000],
          ),
        );

        cubit.onChangedText('bc1qincomplete');
        cubit.onChangedText('bc1qincomplete2');

        expect(cubit.state.recipientDrafts, hasLength(2));
        expect(cubit.state.recipientDrafts.first.address, 'bc1qincomplete2');
        expect(cubit.state.recipientDrafts.first.isValid, isFalse);
        expect(cubit.state.recipientDrafts[1].address, 'bc1qsecond');
        expect(cubit.state.recipientDrafts[1].receivesRemainder, isTrue);
        expect(cubit.state.recipientAmountsSat, isEmpty);

        when(
          () => detectBitcoinStringUsecase.execute(data: 'bc1qnewfirst'),
        ).thenAnswer(
          (_) async => const PaymentRequest.bitcoin(
            address: 'bc1qnewfirst',
            isTestnet: false,
          ),
        );
        cubit.onChangedText('bc1qnewfirst');

        expect(cubit.state.recipientDrafts, hasLength(2));
        expect(cubit.state.recipientDrafts.first.isValid, isFalse);
        expect(await cubit.addRecipient(), isTrue);

        expect(cubit.state.recipientDrafts, hasLength(3));
        expect(cubit.state.recipientDrafts.first.isValid, isTrue);
        expect(cubit.state.recipientDrafts[1].address, 'bc1qsecond');
      },
    );

    test('does not restore an incompatible wallet from a stale sync', () async {
      final bitcoinWallet = _bitcoinLocalWallet();
      final liquidWallet = _liquidWallet(balanceSat: 1000000);
      final liquidSyncs = StreamController<Wallet>.broadcast();
      final bitcoinUtxos = Completer<List<WalletUtxo>>();
      addTearDown(liquidSyncs.close);
      when(
        () => getWalletUtxosUsecase.execute(walletId: liquidWallet.id),
      ).thenAnswer((_) async => const []);
      when(
        () => getWalletUtxosUsecase.execute(walletId: bitcoinWallet.id),
      ).thenAnswer((_) => bitcoinUtxos.future);
      when(
        () =>
            checkLiquidConsolidationUsecase.execute(walletId: liquidWallet.id),
      ).thenAnswer((_) async => false);
      when(
        () =>
            watchFinishedWalletSyncsUsecase.execute(walletId: liquidWallet.id),
      ).thenAnswer((_) => liquidSyncs.stream);
      when(
        () =>
            watchFinishedWalletSyncsUsecase.execute(walletId: bitcoinWallet.id),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => bestWalletUsecase.execute(
          wallets: [bitcoinWallet],
          request: any(named: 'request'),
          amountSat: any(named: 'amountSat'),
        ),
      ).thenReturn(Ok(bitcoinWallet));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.updateSelectedWallet(liquidWallet);
      cubit.setStateForTest(
        SendState(
          sendType: SendType.bitcoin,
          selectedWallet: liquidWallet,
          wallets: [liquidWallet, bitcoinWallet],
          paymentRequest: const PaymentRequest.bitcoin(
            address: 'bc1qfirst',
            isTestnet: false,
          ),
          bitcoinUnit: BitcoinUnit.sats,
          inputAmountCurrencyCode: BitcoinUnit.sats.code,
          bitcoinFeesList: _sweepFeeOptions,
          liquidFeesList: _sweepFeeOptions,
          recipientDrafts: const [
            (
              id: 0,
              address: 'bc1qfirst',
              amount: '10000',
              receivesRemainder: false,
              isValid: true,
            ),
          ],
        ),
      );

      final adding = cubit.addRecipient();
      liquidSyncs.add(liquidWallet);
      bitcoinUtxos.complete(const []);

      expect(await adding, isTrue);
      await pumpEventQueue();
      expect(cubit.state.selectedWallet, bitcoinWallet);
      expect(cubit.state.recipientDrafts, hasLength(2));
    });

    test(
      'does not add a recipient after the primary address changes',
      () async {
        final wallet = _bitcoinLocalWallet();
        final bitcoinUtxos = Completer<List<WalletUtxo>>();
        when(
          () => bestWalletUsecase.execute(
            wallets: [wallet],
            request: any(named: 'request'),
            amountSat: any(named: 'amountSat'),
          ),
        ).thenReturn(Ok(wallet));
        when(
          () => getWalletUtxosUsecase.execute(walletId: wallet.id),
        ).thenAnswer((_) => bitcoinUtxos.future);
        when(
          () => watchFinishedWalletSyncsUsecase.execute(walletId: wallet.id),
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => detectBitcoinStringUsecase.execute(data: 'bc1qnewfirst'),
        ).thenAnswer(
          (_) async => const PaymentRequest.bitcoin(
            address: 'bc1qnewfirst',
            isTestnet: false,
          ),
        );
        final cubit = buildCubit();
        addTearDown(cubit.close);
        cubit.setStateForTest(
          SendState(
            sendType: SendType.bitcoin,
            wallets: [wallet],
            paymentRequest: const PaymentRequest.bitcoin(
              address: 'bc1qfirst',
              isTestnet: false,
            ),
            recipientDrafts: const [
              (
                id: 0,
                address: 'bc1qfirst',
                amount: '10000',
                receivesRemainder: false,
                isValid: true,
              ),
            ],
          ),
        );

        final adding = cubit.addRecipient();
        cubit.onChangedText('bc1qnewfirst');
        bitcoinUtxos.complete(const []);

        expect(await adding, isFalse);
        expect(cubit.state.paymentRequestAddress, 'bc1qnewfirst');
        expect(cubit.state.recipientDrafts, hasLength(1));
        expect(cubit.state.recipientDrafts.single.address, 'bc1qnewfirst');
      },
    );

    test(
      'does not resume address confirmation after the request changes',
      () async {
        final wallet = _bitcoinLocalWallet();
        final bitcoinUtxos = Completer<List<WalletUtxo>>();
        when(
          () => bestWalletUsecase.execute(
            wallets: [wallet],
            request: any(named: 'request'),
            amountSat: any(named: 'amountSat'),
          ),
        ).thenReturn(Ok(wallet));
        when(
          () => getWalletUtxosUsecase.execute(walletId: wallet.id),
        ).thenAnswer((_) => bitcoinUtxos.future);
        when(
          () => watchFinishedWalletSyncsUsecase.execute(walletId: wallet.id),
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => detectBitcoinStringUsecase.execute(data: 'tb1qnew'),
        ).thenAnswer(
          (_) async =>
              const PaymentRequest.bitcoin(address: 'tb1qnew', isTestnet: true),
        );
        final cubit = buildCubit();
        addTearDown(cubit.close);
        cubit.setStateForTest(
          SendState(
            wallets: [wallet],
            paymentRequest: const PaymentRequest.bitcoin(
              address: 'bc1qold',
              isTestnet: false,
            ),
            recipientDrafts: const [
              (
                id: 0,
                address: 'bc1qold',
                amount: '10000',
                receivesRemainder: false,
                isValid: true,
              ),
            ],
          ),
        );

        final continuing = cubit.continueOnAddressConfirmed();
        cubit.onChangedText('tb1qnew');
        bitcoinUtxos.complete(const []);
        await continuing;

        expect(cubit.state.paymentRequestAddress, 'tb1qnew');
        expect(cubit.state.step, SendStep.address);
        expect(cubit.state.loadingBestWallet, isFalse);
        expect(cubit.state.failure, isNull);
        verifyNever(
          () => getNetworkFeesUsecase.execute(isLiquid: any(named: 'isLiquid')),
        );
      },
    );

    test(
      'does not add a recipient without a matching Bitcoin wallet',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        cubit.setStateForTest(
          SendState(
            sendType: SendType.bitcoin,
            wallets: [_liquidWallet(balanceSat: 1000000)],
            paymentRequest: const PaymentRequest.bitcoin(
              address: 'bc1qfirst',
              isTestnet: false,
            ),
            recipientDrafts: const [
              (
                id: 0,
                address: 'bc1qfirst',
                amount: '10000',
                receivesRemainder: false,
                isValid: true,
              ),
            ],
          ),
        );

        expect(await cubit.addRecipient(), isFalse);
        expect(cubit.state.recipientDrafts, hasLength(1));
        expect(cubit.state.failure, isA<SendInsufficientBalanceFailure>());
        verifyNever(
          () => bestWalletUsecase.execute(
            wallets: any(named: 'wallets'),
            request: any(named: 'request'),
            amountSat: any(named: 'amountSat'),
          ),
        );
      },
    );

    test(
      'adds recipients with an explicitly supplied watch-only wallet',
      () async {
        final wallet = _bitcoinWatchOnlyWallet();
        stubSweepLoad(wallet: wallet, utxos: const []);
        when(
          () => detectBitcoinStringUsecase.execute(data: 'bc1qfirst'),
        ).thenAnswer(
          (_) async => const PaymentRequest.bitcoin(
            address: 'bc1qfirst',
            isTestnet: false,
          ),
        );
        when(
          () => bestWalletUsecase.execute(
            wallets: [wallet],
            request: any(named: 'request'),
            amountSat: 0,
          ),
        ).thenReturn(
          const Err<Wallet, SendFailure>(SendInsufficientBalanceFailure()),
        );
        final cubit = buildCubit(wallet: wallet);
        addTearDown(cubit.close);

        await cubit.loadWalletWithRatesAndFees();
        cubit.onChangedText('bc1qfirst');

        expect(await cubit.addRecipient(), isTrue);
        expect(cubit.state.bitcoinRecipientWallets, [wallet]);
        expect(cubit.state.selectedWallet, wallet);
        expect(cubit.state.recipientDrafts, hasLength(2));
      },
    );

    test('keeps a multi-recipient BIP21 send on chain', () async {
      final wallet = _bitcoinLocalWallet();
      const request = PaymentRequest.bip21(
        network: Network.bitcoinMainnet,
        uri: 'bitcoin:bc1qfirst?lightning=lnbc1invoice',
        address: 'bc1qfirst',
        lightning: 'lnbc1invoice',
      );
      var parsedLightning = false;
      when(
        () => bestWalletUsecase.execute(
          wallets: [wallet],
          request: request,
          amountSat: 30000,
        ),
      ).thenReturn(Ok(wallet));
      when(
        () => getWalletUtxosUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) async => const []);
      when(
        () => watchFinishedWalletSyncsUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => getNetworkFeesUsecase.execute(isLiquid: any(named: 'isLiquid')),
      ).thenAnswer((_) async => _sweepFeeOptions);
      final cubit = buildCubit(
        parsePaymentRequest: (_) async {
          parsedLightning = true;
          throw StateError('multi-recipient BIP21 must remain on chain');
        },
      );
      addTearDown(cubit.close);
      cubit.setStateForTest(
        readyState(wallet).copyWith(
          wallets: [wallet],
          selectedWallet: null,
          paymentRequest: request,
        ),
      );

      await cubit.continueOnAddressConfirmed();

      expect(parsedLightning, isFalse);
      expect(cubit.state.paymentRequest, request);
      expect(cubit.state.sendType, SendType.bitcoin);
      expect(cubit.state.step, SendStep.amount);
    });

    test('keeps a manually selected wallet when continuing', () async {
      final automaticWallet = _bitcoinLocalWallet();
      final selectedWallet = _bitcoinWallet(balanceSat: 500000);
      when(
        () => watchFinishedWalletSyncsUsecase.execute(
          walletId: selectedWallet.id,
        ),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => getNetworkFeesUsecase.execute(isLiquid: any(named: 'isLiquid')),
      ).thenAnswer((_) async => _sweepFeeOptions);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        readyState(selectedWallet).copyWith(
          wallets: [automaticWallet, selectedWallet],
          isWalletManuallySelected: true,
        ),
      );

      await cubit.continueOnAddressConfirmed();

      expect(cubit.state.selectedWallet, selectedWallet);
      expect(cubit.state.isWalletManuallySelected, isTrue);
      expect(cubit.state.step, SendStep.amount);
      verifyNever(
        () => bestWalletUsecase.execute(
          wallets: any(named: 'wallets'),
          request: any(named: 'request'),
          amountSat: any(named: 'amountSat'),
        ),
      );
    });

    test('refreshes the remainder after switching Bitcoin wallets', () async {
      final firstWallet = _bitcoinLocalWallet();
      final secondWallet = _bitcoinWallet(balanceSat: 500000);
      final previewStarted = Completer<void>();
      when(
        () => getWalletUtxosUsecase.execute(walletId: secondWallet.id),
      ).thenAnswer((_) async => const []);
      when(
        () =>
            watchFinishedWalletSyncsUsecase.execute(walletId: secondWallet.id),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => previewBitcoinFeeUsecase.execute(
          walletId: secondWallet.id,
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          replaceByFee: true,
          selectedInputs: const [],
          selectedOnly: false,
        ),
      ).thenAnswer((_) async {
        previewStarted.complete();
        return const BitcoinFeePreviewSlot(
          feeSat: 1000,
          unsignedPsbt: 'second-wallet-preview',
          txSize: 140,
          recipientAmountsSat: [10000, 489000],
          isToSelf: false,
        );
      });
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        readyState(firstWallet).copyWith(
          wallets: [firstWallet, secondWallet],
          recipientDrafts: const [
            (
              id: 0,
              address: 'bc1qfirst',
              amount: '10000',
              receivesRemainder: false,
              isValid: true,
            ),
            (
              id: 1,
              address: 'bc1qsecond',
              amount: '',
              receivesRemainder: true,
              isValid: true,
            ),
          ],
          recipientAmountsSat: const [10000, 989000],
        ),
      );

      final switching = cubit.updateSelectedWallet(secondWallet);
      await pumpEventQueue();
      expect(cubit.state.recipientAmountsSat, isEmpty);
      await switching;
      await previewStarted.future;
      await pumpEventQueue();

      expect(cubit.state.recipientAmountsSat, [10000, 489000]);
    });

    test('switches wallets before waiting for the old sync to stop', () async {
      final firstWallet = _bitcoinLocalWallet();
      final secondWallet = _bitcoinWallet(balanceSat: 500000);
      final cancelRequested = Completer<void>();
      final allowCancel = Completer<void>();
      final firstWalletSyncs = StreamController<Wallet>(
        onCancel: () {
          cancelRequested.complete();
          return allowCancel.future;
        },
      );
      addTearDown(firstWalletSyncs.close);
      when(
        () => watchFinishedWalletSyncsUsecase.execute(walletId: firstWallet.id),
      ).thenAnswer((_) => firstWalletSyncs.stream);
      when(
        () =>
            watchFinishedWalletSyncsUsecase.execute(walletId: secondWallet.id),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => getWalletUtxosUsecase.execute(walletId: secondWallet.id),
      ).thenAnswer((_) async => const []);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(readyState(firstWallet));
      await cubit.updateSelectedWallet(firstWallet);
      cubit.setStateForTest(
        cubit.state.copyWith(
          unsignedPsbt: 'old-unsigned',
          signedBitcoinPsbt: 'old-signed',
          buildingTransaction: true,
        ),
      );

      final switching = cubit.updateSelectedWallet(secondWallet);
      await cancelRequested.future;

      expect(cubit.state.selectedWallet, secondWallet);
      expect(cubit.state.unsignedPsbt, isNull);
      expect(cubit.state.signedBitcoinPsbt, isNull);
      expect(cubit.state.buildingTransaction, isFalse);

      allowCancel.complete();
      await switching;
    });

    test('discards a transaction build when the wallet changes', () async {
      final firstWallet = _bitcoinLocalWallet();
      final secondWallet = _bitcoinWallet(balanceSat: 500000);
      final prepareStarted = Completer<void>();
      final prepared =
          Completer<
            ({
              String unsignedPsbt,
              int txSize,
              bool isToSelf,
              List<Sats> recipientAmountsSat,
            })
          >();
      when(
        () => getWalletUtxosUsecase.execute(walletId: firstWallet.id),
      ).thenAnswer((_) async => const []);
      when(
        () => getWalletUtxosUsecase.execute(walletId: secondWallet.id),
      ).thenAnswer((_) async => const []);
      when(
        () =>
            watchFinishedWalletSyncsUsecase.execute(walletId: secondWallet.id),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => prepareBitcoinSendUsecase.execute(
          walletId: firstWallet.id,
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          replaceByFee: true,
          selectedInputs: const [],
          selectedOnly: false,
        ),
      ).thenAnswer((_) {
        prepareStarted.complete();
        return prepared.future;
      });
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(readyState(firstWallet));

      final building = cubit.createTransaction();
      await prepareStarted.future;
      await cubit.updateSelectedWallet(secondWallet);
      prepared.complete((
        unsignedPsbt: 'old-wallet-psbt',
        txSize: 140,
        recipientAmountsSat: [Sats.fromInt(10000), Sats.fromInt(20000)],
        isToSelf: false,
      ));

      expect(await building, isFalse);
      expect(cubit.state.selectedWallet, secondWallet);
      expect(cubit.state.unsignedPsbt, isNull);
      expect(cubit.state.signedBitcoinPsbt, isNull);
    });

    test(
      'shows the built MAX amount while preserving its fixed fallback',
      () async {
        final wallet = _bitcoinLocalWallet();
        when(
          () => getWalletUtxosUsecase.execute(walletId: wallet.id),
        ).thenAnswer((_) async => const []);
        when(
          () => prepareBitcoinSendUsecase.execute(
            walletId: wallet.id,
            recipients: any(named: 'recipients'),
            networkFee: any(named: 'networkFee'),
            replaceByFee: true,
            selectedInputs: const [],
            selectedOnly: false,
          ),
        ).thenAnswer(
          (_) async => (
            unsignedPsbt: 'unsigned-remainder',
            txSize: 110,
            recipientAmountsSat: [Sats.fromInt(999000)],
            isToSelf: false,
          ),
        );
        when(
          () => calculateBitcoinAbsoluteFeesUsecase.execute(
            psbt: any(named: 'psbt'),
          ),
        ).thenAnswer((_) async => 1000);
        when(
          () => signBitcoinTxUsecase.execute(
            psbt: 'unsigned-remainder',
            walletId: wallet.id,
          ),
        ).thenAnswer((_) async => (signedPsbt: 'signed', txSize: 110));
        final cubit = buildCubit();
        addTearDown(cubit.close);
        cubit.setStateForTest(
          readyState(wallet).copyWith(
            amount: '10000',
            recipientDrafts: const [
              (
                id: 0,
                address: 'bc1qfirst',
                amount: '10000',
                receivesRemainder: true,
                isValid: true,
              ),
            ],
          ),
        );

        await cubit.createTransaction();

        expect(cubit.state.amount, '999000');
        expect(cubit.state.confirmedAmountSat, 999000);
        cubit.setRemainderRecipient(0, false);
        expect(
          cubit.state.bitcoinTransactionRecipients.single.amountSat,
          Sats.fromInt(10000),
        );
      },
    );

    test('previews the remainder after a fixed amount changes', () async {
      final wallet = _bitcoinLocalWallet();
      final preview = Completer<BitcoinFeePreviewSlot>();
      late List<BitcoinTransactionRecipient> previewedRecipients;
      when(
        () => previewBitcoinFeeUsecase.execute(
          walletId: wallet.id,
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          replaceByFee: true,
          selectedInputs: const [],
          selectedOnly: false,
        ),
      ).thenAnswer((invocation) {
        previewedRecipients =
            invocation.namedArguments[#recipients]
                as List<BitcoinTransactionRecipient>;
        return preview.future;
      });
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        readyState(wallet).copyWith(
          recipientDrafts: const [
            (
              id: 0,
              address: 'bc1qfirst',
              amount: '10000',
              receivesRemainder: false,
              isValid: true,
            ),
            (
              id: 1,
              address: 'bc1qsecond',
              amount: '',
              receivesRemainder: true,
              isValid: true,
            ),
          ],
        ),
      );

      await cubit.recipientAmountChanged(0, '12000');
      await untilCalled(
        () => previewBitcoinFeeUsecase.execute(
          walletId: wallet.id,
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          replaceByFee: true,
          selectedInputs: const [],
          selectedOnly: false,
        ),
      );
      expect(previewedRecipients.map((recipient) => recipient.amountSat), [
        Sats.fromInt(12000),
        null,
      ]);
      preview.complete(
        const BitcoinFeePreviewSlot(
          feeSat: 1000,
          unsignedPsbt: 'preview',
          txSize: 140,
          recipientAmountsSat: [12000, 987000],
          isToSelf: false,
        ),
      );
      await pumpEventQueue();

      expect(cubit.state.recipientAmountsSat, [12000, 987000]);
      expect(cubit.state.bitcoinAbsoluteFeesSat, 1000);
    });

    test('ignores a slower remainder preview after a newer edit', () async {
      final wallet = _bitcoinLocalWallet();
      final previews = <Completer<BitcoinFeePreviewSlot>>[];
      final firstStarted = Completer<void>();
      final secondStarted = Completer<void>();
      when(
        () => previewBitcoinFeeUsecase.execute(
          walletId: wallet.id,
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          replaceByFee: true,
          selectedInputs: const [],
          selectedOnly: false,
        ),
      ).thenAnswer((_) {
        final preview = Completer<BitcoinFeePreviewSlot>();
        previews.add(preview);
        if (previews.length == 1) firstStarted.complete();
        if (previews.length == 2) secondStarted.complete();
        return preview.future;
      });
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        readyState(wallet).copyWith(
          recipientDrafts: const [
            (
              id: 0,
              address: 'bc1qfirst',
              amount: '10000',
              receivesRemainder: false,
              isValid: true,
            ),
            (
              id: 1,
              address: 'bc1qsecond',
              amount: '',
              receivesRemainder: true,
              isValid: true,
            ),
          ],
        ),
      );

      await cubit.recipientAmountChanged(0, '11000');
      await firstStarted.future;
      await cubit.recipientAmountChanged(0, '12000');
      await secondStarted.future;

      previews[1].complete(
        const BitcoinFeePreviewSlot(
          feeSat: 1200,
          unsignedPsbt: 'new-preview',
          txSize: 140,
          recipientAmountsSat: [12000, 986800],
          isToSelf: false,
        ),
      );
      await pumpEventQueue();
      previews[0].complete(
        const BitcoinFeePreviewSlot(
          feeSat: 1100,
          unsignedPsbt: 'old-preview',
          txSize: 140,
          recipientAmountsSat: [11000, 987900],
          isToSelf: false,
        ),
      );
      await pumpEventQueue();

      expect(cubit.state.recipientAmountsSat, [12000, 986800]);
      expect(cubit.state.bitcoinAbsoluteFeesSat, 1200);
    });

    test(
      'keeps the newest transaction when fee builds finish out of order',
      () async {
        final wallet = _bitcoinLocalWallet();
        final builds =
            <
              Completer<
                ({
                  String unsignedPsbt,
                  int txSize,
                  List<Sats> recipientAmountsSat,
                  bool isToSelf,
                })
              >
            >[];
        final firstStarted = Completer<void>();
        final secondStarted = Completer<void>();
        when(
          () => getWalletUtxosUsecase.execute(walletId: wallet.id),
        ).thenAnswer((_) async => const []);
        when(
          () => prepareBitcoinSendUsecase.execute(
            walletId: wallet.id,
            recipients: any(named: 'recipients'),
            networkFee: any(named: 'networkFee'),
            replaceByFee: true,
            selectedInputs: any(named: 'selectedInputs'),
            selectedOnly: false,
          ),
        ).thenAnswer((_) {
          final build =
              Completer<
                ({
                  String unsignedPsbt,
                  int txSize,
                  List<Sats> recipientAmountsSat,
                  bool isToSelf,
                })
              >();
          builds.add(build);
          if (builds.length == 1) firstStarted.complete();
          if (builds.length == 2) secondStarted.complete();
          return build.future;
        });
        when(
          () => calculateBitcoinAbsoluteFeesUsecase.execute(
            psbt: any(named: 'psbt'),
          ),
        ).thenAnswer((_) async => 1000);
        when(
          () => signBitcoinTxUsecase.execute(
            psbt: any(named: 'psbt'),
            walletId: wallet.id,
          ),
        ).thenAnswer(
          (invocation) async => (
            signedPsbt: 'signed-${invocation.namedArguments[#psbt]}',
            txSize: 140,
          ),
        );
        final cubit = buildCubit();
        addTearDown(cubit.close);
        cubit.setStateForTest(readyState(wallet));

        final olderSelection = cubit.feeOptionSelected(FeeSelection.economic);
        await firstStarted.future;
        final newerSelection = cubit.feeOptionSelected(FeeSelection.slow);
        await secondStarted.future;
        builds[1].complete((
          unsignedPsbt: 'newer',
          txSize: 140,
          recipientAmountsSat: [Sats.fromInt(10000), Sats.fromInt(20000)],
          isToSelf: false,
        ));
        await newerSelection;
        builds[0].complete((
          unsignedPsbt: 'older',
          txSize: 140,
          recipientAmountsSat: [Sats.fromInt(10000), Sats.fromInt(20000)],
          isToSelf: false,
        ));
        await olderSelection;

        expect(cubit.state.selectedFeeOption, FeeSelection.slow);
        expect(cubit.state.unsignedPsbt, 'newer');
        expect(cubit.state.signedBitcoinPsbt, 'signed-newer');
      },
    );

    test(
      'does not broadcast an earlier transaction after a rebuild fails',
      () async {
        final wallet = _bitcoinLocalWallet();
        when(
          () => getWalletUtxosUsecase.execute(walletId: wallet.id),
        ).thenAnswer((_) async => const []);
        when(
          () => prepareBitcoinSendUsecase.execute(
            walletId: wallet.id,
            recipients: any(named: 'recipients'),
            networkFee: any(named: 'networkFee'),
            replaceByFee: true,
            selectedInputs: any(named: 'selectedInputs'),
            selectedOnly: false,
          ),
        ).thenThrow(InsufficientFundsException('remainder is dust'));
        final cubit = buildCubit();
        addTearDown(cubit.close);
        cubit.setStateForTest(
          readyState(wallet).copyWith(
            step: SendStep.confirm,
            unsignedPsbt: 'old-unsigned',
            signedBitcoinPsbt: 'old-signed',
            recipientAmountsSat: const [10000, 20000],
          ),
        );

        await cubit.feeOptionSelected(FeeSelection.economic);

        expect(cubit.state.unsignedPsbt, isNull);
        expect(cubit.state.signedBitcoinPsbt, isNull);
        expect(cubit.state.recipientAmountsSat, isEmpty);
        expect(cubit.state.confirmedAmountSat, isNull);
        expect(cubit.state.failure, isA<SendInsufficientFundsForFeesFailure>());
        expect(cubit.state.disableConfirmSend, isTrue);

        await cubit.onConfirmTransactionClicked();

        expect(cubit.state.step, SendStep.confirm);
        expect(cubit.state.signedBitcoinPsbt, isNull);
        verifyNever(
          () => broadcastBitcoinTxUsecase.execute(
            any(),
            isPsbt: any(named: 'isPsbt'),
          ),
        );
      },
    );

    test(
      'invalidates a prepared transaction when wallet UTXOs change',
      () async {
        final wallet = _bitcoinLocalWallet();
        final oldUtxo = walletUtxoFixture(
          walletId: wallet.id,
          txId: 'old',
          sats: 50000,
        );
        final newUtxo = walletUtxoFixture(
          walletId: wallet.id,
          txId: 'new',
          sats: 60000,
        );
        when(
          () => getWalletUtxosUsecase.execute(walletId: wallet.id),
        ).thenAnswer((_) async => [newUtxo]);
        when(
          () => prepareBitcoinSendUsecase.execute(
            walletId: wallet.id,
            recipients: any(named: 'recipients'),
            networkFee: any(named: 'networkFee'),
            replaceByFee: true,
            selectedInputs: any(named: 'selectedInputs'),
            selectedOnly: false,
          ),
        ).thenThrow(InsufficientFundsException('remainder is unavailable'));
        final cubit = buildCubit();
        addTearDown(cubit.close);
        cubit.setStateForTest(
          readyState(wallet).copyWith(
            step: SendStep.confirm,
            utxos: [oldUtxo],
            unsignedPsbt: 'old-unsigned',
            signedBitcoinPsbt: 'old-signed',
            recipientAmountsSat: const [10000, 39000],
          ),
        );

        await cubit.loadUtxos();

        expect(cubit.state.unsignedPsbt, isNull);
        expect(cubit.state.signedBitcoinPsbt, isNull);
        expect(cubit.state.recipientAmountsSat, isEmpty);

        await cubit.onConfirmTransactionClicked();

        expect(cubit.state.step, SendStep.confirm);
        verifyNever(
          () => broadcastBitcoinTxUsecase.execute(
            any(),
            isPsbt: any(named: 'isPsbt'),
          ),
        );
      },
    );

    test(
      'rebuilds a watch-only transaction when wallet UTXOs change',
      () async {
        final wallet = _bitcoinWatchOnlyWallet();
        final oldUtxo = walletUtxoFixture(
          walletId: wallet.id,
          txId: 'old',
          sats: 50000,
        );
        final newUtxo = walletUtxoFixture(
          walletId: wallet.id,
          txId: 'new',
          sats: 60000,
        );
        when(
          () => getWalletUtxosUsecase.execute(walletId: wallet.id),
        ).thenAnswer((_) async => [newUtxo]);
        when(
          () => prepareBitcoinSendUsecase.execute(
            walletId: wallet.id,
            recipients: any(named: 'recipients'),
            networkFee: any(named: 'networkFee'),
            replaceByFee: true,
            selectedInputs: any(named: 'selectedInputs'),
            selectedOnly: false,
          ),
        ).thenAnswer(
          (_) async => (
            unsignedPsbt: 'fresh-unsigned',
            txSize: 140,
            isToSelf: false,
            recipientAmountsSat: [Sats.fromInt(10000), Sats.fromInt(49900)],
          ),
        );
        when(
          () => calculateBitcoinAbsoluteFeesUsecase.execute(
            psbt: 'fresh-unsigned',
          ),
        ).thenAnswer((_) async => 100);
        final cubit = buildCubit();
        addTearDown(cubit.close);
        cubit.setStateForTest(
          readyState(wallet).copyWith(
            step: SendStep.confirm,
            utxos: [oldUtxo],
            unsignedPsbt: 'old-unsigned',
            recipientAmountsSat: const [10000, 39900],
          ),
        );

        await cubit.loadUtxos();

        expect(cubit.state.unsignedPsbt, 'fresh-unsigned');
        expect(cubit.state.signedBitcoinPsbt, isNull);
        expect(cubit.state.recipientAmountsSat, [10000, 49900]);
        verifyNever(
          () => signBitcoinTxUsecase.execute(
            psbt: any(named: 'psbt'),
            walletId: any(named: 'walletId'),
          ),
        );
      },
    );

    test('keeps the newest same-wallet UTXO refresh', () async {
      final wallet = _bitcoinLocalWallet();
      final selected = walletUtxoFixture(
        walletId: wallet.id,
        txId: 'selected',
        sats: 50000,
      );
      final staleLoad = Completer<List<WalletUtxo>>();
      final latestLoad = Completer<List<WalletUtxo>>();
      var loadCount = 0;
      when(() => getWalletUtxosUsecase.execute(walletId: wallet.id)).thenAnswer(
        (_) => loadCount++ == 0 ? staleLoad.future : latestLoad.future,
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        readyState(wallet).copyWith(
          step: SendStep.amount,
          sweepOutpoints: const {(txId: 'selected', vout: 0)},
          utxos: [selected],
          selectedUtxos: [selected],
        ),
      );

      final staleRefresh = cubit.loadUtxos();
      final latestRefresh = cubit.loadUtxos();
      latestLoad.complete(const []);
      await latestRefresh;
      staleLoad.complete([selected]);
      await staleRefresh;

      expect(cubit.state.utxos, isEmpty);
      expect(cubit.state.selectedUtxos, isEmpty);
      expect(cubit.state.failure, isA<SendSelectedCoinsUnavailableFailure>());
    });

    test('does not confirm a transaction canceled while building', () async {
      final wallet = _bitcoinWatchOnlyWallet();
      final buildStarted = Completer<void>();
      final build =
          Completer<
            ({
              String unsignedPsbt,
              int txSize,
              bool isToSelf,
              List<Sats> recipientAmountsSat,
            })
          >();
      when(
        () => getWalletUtxosUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) async => const []);
      when(
        () => prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          replaceByFee: true,
          selectedInputs: any(named: 'selectedInputs'),
          selectedOnly: false,
        ),
      ).thenAnswer((_) {
        buildStarted.complete();
        return build.future;
      });
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(readyState(wallet).copyWith(step: SendStep.amount));

      final confirming = cubit.onAmountConfirmed();
      await buildStarted.future;
      cubit.backClicked();
      build.complete((
        unsignedPsbt: 'canceled',
        txSize: 140,
        isToSelf: false,
        recipientAmountsSat: [Sats.fromInt(10000), Sats.fromInt(20000)],
      ));
      await confirming;

      expect(cubit.state.step, SendStep.address);
      expect(cubit.state.unsignedPsbt, isNull);
      expect(cubit.state.amountConfirmedClicked, isFalse);
      verifyNever(
        () => calculateBitcoinAbsoluteFeesUsecase.execute(
          psbt: any(named: 'psbt'),
        ),
      );
    });

    test('local signing keeps all prepared recipient amounts', () async {
      final wallet = _bitcoinLocalWallet();
      stubMultiRecipientBuild(wallet);
      when(
        () =>
            signBitcoinTxUsecase.execute(psbt: 'unsigned', walletId: wallet.id),
      ).thenAnswer((_) async => (signedPsbt: 'signed', txSize: 140));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(readyState(wallet));

      await cubit.createTransaction();

      final recipients =
          verify(
                () => prepareBitcoinSendUsecase.execute(
                  walletId: wallet.id,
                  recipients: captureAny(named: 'recipients'),
                  networkFee: any(named: 'networkFee'),
                  replaceByFee: true,
                  selectedInputs: any(named: 'selectedInputs'),
                  selectedOnly: false,
                ),
              ).captured.single
              as List<BitcoinTransactionRecipient>;
      expect(recipients.map((recipient) => recipient.amountSat), [
        Sats.fromInt(10000),
        Sats.fromInt(20000),
      ]);
      expect(cubit.state.recipientAmountsSat, [10000, 20000]);
      expect(cubit.state.signedBitcoinPsbt, 'signed');
    });

    for (final entry in [
      (name: 'watch-only', wallet: _bitcoinWatchOnlyWallet()),
      (name: 'hardware', wallet: _bitcoinHardwareWallet()),
    ]) {
      test(
        '${entry.name} preparation keeps all recipient amounts unsigned',
        () async {
          stubMultiRecipientBuild(entry.wallet);
          final cubit = buildCubit();
          addTearDown(cubit.close);
          cubit.setStateForTest(readyState(entry.wallet));

          await cubit.createTransaction();

          final recipients =
              verify(
                    () => prepareBitcoinSendUsecase.execute(
                      walletId: entry.wallet.id,
                      recipients: captureAny(named: 'recipients'),
                      networkFee: any(named: 'networkFee'),
                      replaceByFee: true,
                      selectedInputs: any(named: 'selectedInputs'),
                      selectedOnly: false,
                    ),
                  ).captured.single
                  as List<BitcoinTransactionRecipient>;
          expect(recipients.map((recipient) => recipient.amountSat), [
            Sats.fromInt(10000),
            Sats.fromInt(20000),
          ]);
          expect(cubit.state.recipientAmountsSat, [10000, 20000]);
          expect(cubit.state.unsignedPsbt, 'unsigned');
          expect(cubit.state.signedBitcoinPsbt, isNull);
          verifyNever(
            () => signBitcoinTxUsecase.execute(
              psbt: any(named: 'psbt'),
              walletId: any(named: 'walletId'),
            ),
          );
        },
      );
    }

    test('never starts a chain swap for multiple recipients', () async {
      final liquidWallet = _liquidWallet(balanceSat: 1000000);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(readyState(liquidWallet));

      await cubit.onAmountConfirmed();

      expect(cubit.state.failure, isA<SendInvalidPaymentRequestFailure>());
      expect(cubit.state.chainSwap, isNull);
      verifyNever(
        () => createSendCrossChainSwapUsecase.execute(
          walletId: any(named: 'walletId'),
          destinationAddress: any(named: 'destinationAddress'),
          destinationIsTestnet: any(named: 'destinationIsTestnet'),
          amountSat: any(named: 'amountSat'),
          isInAmountFixed: any(named: 'isInAmountFixed'),
          quotedCounterpartAmountSat: any(named: 'quotedCounterpartAmountSat'),
          note: any(named: 'note'),
        ),
      );
      verifyNever(
        () => prepareLiquidSendUsecase.execute(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
          feeRate: any(named: 'feeRate'),
          amountSat: any(named: 'amountSat'),
          drain: any(named: 'drain'),
        ),
      );
    });

    for (final invalidDrafts in [
      const [
        (
          id: 0,
          address: 'bc1qfirst',
          amount: '10000',
          receivesRemainder: false,
          isValid: true,
        ),
        (
          id: 1,
          address: 'invalid',
          amount: '20000',
          receivesRemainder: false,
          isValid: false,
        ),
      ],
      const [
        (
          id: 0,
          address: 'bc1qfirst',
          amount: '0',
          receivesRemainder: false,
          isValid: true,
        ),
        (
          id: 1,
          address: 'bc1qsecond',
          amount: '20000',
          receivesRemainder: false,
          isValid: true,
        ),
      ],
    ]) {
      test(
        'rejects an invalid multi-recipient draft before building',
        () async {
          final cubit = buildCubit();
          addTearDown(cubit.close);
          cubit.setStateForTest(
            readyState(
              _bitcoinLocalWallet(),
            ).copyWith(recipientDrafts: invalidDrafts),
          );

          await cubit.onAmountConfirmed();

          expect(cubit.state.failure, isA<SendInvalidPaymentRequestFailure>());
          verifyNever(
            () => prepareBitcoinSendUsecase.execute(
              walletId: any(named: 'walletId'),
              recipients: any(named: 'recipients'),
              networkFee: any(named: 'networkFee'),
              replaceByFee: any(named: 'replaceByFee'),
              selectedInputs: any(named: 'selectedInputs'),
              selectedOnly: any(named: 'selectedOnly'),
            ),
          );
        },
      );
    }

    test('reports an aggregate multi-recipient shortfall', () async {
      final wallet = _bitcoinLocalWallet();
      when(
        () => getWalletUtxosUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) async => const []);
      when(
        () => prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          replaceByFee: true,
          selectedInputs: any(named: 'selectedInputs'),
          selectedOnly: false,
        ),
      ).thenThrow(InsufficientFundsException('outputs exceed wallet balance'));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(readyState(wallet));

      await cubit.createTransaction();

      expect(cubit.state.failure, isA<SendInsufficientFundsForFeesFailure>());
      expect(cubit.state.step, SendStep.address);
      expect(cubit.state.unsignedPsbt, isNull);
      final recipients =
          verify(
                () => prepareBitcoinSendUsecase.execute(
                  walletId: wallet.id,
                  recipients: captureAny(named: 'recipients'),
                  networkFee: any(named: 'networkFee'),
                  replaceByFee: true,
                  selectedInputs: any(named: 'selectedInputs'),
                  selectedOnly: false,
                ),
              ).captured.single
              as List<BitcoinTransactionRecipient>;
      expect(recipients.map((recipient) => recipient.address), [
        'bc1qfirst',
        'bc1qsecond',
      ]);
      expect(recipients.map((recipient) => recipient.amountSat), [
        Sats.fromInt(10000),
        Sats.fromInt(20000),
      ]);
    });
  });

  group('SendCubit direct non-Bitcoin requests', () {
    test('routes a zero-amount Lightning invoice to amount entry', () async {
      final wallet = _bitcoinLocalWallet();
      final request = PaymentRequest.bolt11(
        invoice: 'lnbc1invoice',
        amountSat: 0,
        paymentHash: 'hash',
        expiresAt: DateTime(2030).millisecondsSinceEpoch ~/ 1000,
        isTestnet: false,
      );
      when(
        () => bestWalletUsecase.execute(
          wallets: [wallet],
          request: request,
          amountSat: 0,
        ),
      ).thenReturn(Ok(wallet));
      when(
        () => getWalletUtxosUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) async => const []);
      when(
        () => watchFinishedWalletSyncsUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => getNetworkFeesUsecase.execute(isLiquid: any(named: 'isLiquid')),
      ).thenAnswer((_) async => _sweepFeeOptions);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        SendState(
          wallets: [wallet],
          paymentRequest: request,
          recipientDrafts: const [
            (
              id: 0,
              address: 'lnbc1invoice',
              amount: '',
              receivesRemainder: false,
              isValid: false,
            ),
          ],
        ),
      );

      await cubit.continueOnAddressConfirmed();

      expect(cubit.state.failure, isNull);
      expect(cubit.state.sendType, SendType.lightning);
      expect(cubit.state.step, SendStep.amount);
    });

    test('routes a Liquid address to amount entry', () async {
      final wallet = _liquidWallet(balanceSat: 1000000);
      const request = PaymentRequest.liquid(
        address: 'lq1address',
        isTestnet: false,
      );
      when(
        () => bestWalletUsecase.execute(
          wallets: [wallet],
          request: request,
          amountSat: null,
        ),
      ).thenReturn(Ok(wallet));
      when(
        () => getWalletUtxosUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) async => const []);
      when(
        () => checkLiquidConsolidationUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) async => false);
      when(
        () => watchFinishedWalletSyncsUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => getNetworkFeesUsecase.execute(isLiquid: any(named: 'isLiquid')),
      ).thenAnswer((_) async => _sweepFeeOptions);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        SendState(
          wallets: [wallet],
          paymentRequest: request,
          recipientDrafts: const [
            (
              id: 0,
              address: 'lq1address',
              amount: '',
              receivesRemainder: false,
              isValid: false,
            ),
          ],
        ),
      );

      await cubit.continueOnAddressConfirmed();

      expect(cubit.state.failure, isNull);
      expect(cubit.state.sendType, SendType.liquid);
      expect(cubit.state.step, SendStep.amount);
    });
  });

  group('SendCubit._watchPayjoin', () {
    test(
      'confirm starts payjoin even when the regular PSBT was pre-signed',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        when(
          () => sendWithPayjoinUsecase.execute(
            walletId: any(named: 'walletId'),
            isTestnet: any(named: 'isTestnet'),
            bip21: any(named: 'bip21'),
            unsignedOriginalPsbt: any(named: 'unsignedOriginalPsbt'),
            amountSat: any(named: 'amountSat'),
            networkFeesSatPerVb: any(named: 'networkFeesSatPerVb'),
          ),
        ).thenAnswer(
          (_) async => Ok<PayjoinSenderSession, SendFailure>(
            _sender(status: PayjoinStatus.requested),
          ),
        );
        cubit.setStateForTest(
          payjoinReadyState().copyWith(
            signedBitcoinPsbt: 'signed-regular-psbt',
          ),
        );

        await cubit.onConfirmTransactionClicked();

        expect(cubit.state.step, SendStep.sending);
        expect(cubit.state.payjoinSender?.status, PayjoinStatus.requested);
        verify(
          () => sendWithPayjoinUsecase.execute(
            walletId: 'w1',
            isTestnet: false,
            bip21: any(named: 'bip21'),
            unsignedOriginalPsbt: 'cHNidP8=',
            amountSat: 50000,
            networkFeesSatPerVb: 2,
          ),
        ).called(1);
        verifyNever(
          () => broadcastBitcoinTxUsecase.execute(
            any(),
            isPsbt: any(named: 'isPsbt'),
          ),
        );
      },
    );

    // The payjoin-only path skips createTransaction(), so nothing else clears
    // a failure left by the previous attempt and every retry gets trapped.
    test(
      'a failed payjoin start can be retried from the confirm screen',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        var attempts = 0;
        when(
          () => sendWithPayjoinUsecase.execute(
            walletId: any(named: 'walletId'),
            isTestnet: any(named: 'isTestnet'),
            bip21: any(named: 'bip21'),
            unsignedOriginalPsbt: any(named: 'unsignedOriginalPsbt'),
            amountSat: any(named: 'amountSat'),
            networkFeesSatPerVb: any(named: 'networkFeesSatPerVb'),
          ),
        ).thenAnswer((_) async {
          attempts++;
          if (attempts == 1) {
            return const Err<PayjoinSenderSession, SendFailure>(
              SendTransactionConfirmationFailure(
                logMessage: 'payjoin directory unreachable',
              ),
            );
          }
          return Ok<PayjoinSenderSession, SendFailure>(
            _sender(status: PayjoinStatus.requested),
          );
        });
        cubit.setStateForTest(
          payjoinReadyState().copyWith(
            signedBitcoinPsbt: 'signed-regular-psbt',
          ),
        );

        await cubit.onConfirmTransactionClicked();
        expect(cubit.state.step, SendStep.confirm);
        expect(cubit.state.failure, isA<SendTransactionConfirmationFailure>());

        await cubit.onConfirmTransactionClicked();

        expect(attempts, 2);
        expect(cubit.state.step, SendStep.sending);
        expect(cubit.state.payjoinSender?.status, PayjoinStatus.requested);
      },
    );

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
      expect(cubit.state.failure, isA<SendTransactionConfirmationFailure>());
      expect(
        (cubit.state.failure! as SendTransactionConfirmationFailure)
            .isBroadcastFailure,
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
        expect(cubit.state.failure, isNull);
      },
    );
  });

  group('SendCubit — hardware-signer transaction verification', () {
    SendState hardwareSignReadyState() => SendState(
      step: SendStep.confirm,
      sendType: SendType.bitcoin,
      selectedWallet: _bitcoinLocalWallet(),
      unsignedPsbt: 'cHNidP8=',
      confirmedAmountSat: 50000,
    );

    test('a signed transaction that fails verification is refused and never '
        'stored for broadcast', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(hardwareSignReadyState());
      when(
        () => verifySignedTxUsecase.execute(
          unsignedPsbt: any(named: 'unsignedPsbt'),
          signedTransaction: any(named: 'signedTransaction'),
        ),
      ).thenAnswer(
        (_) async => const Err<void, SendFailure>(
          SendTransactionConfirmationFailure(
            logMessage: 'The signed transaction does not match',
          ),
        ),
      );

      await cubit.updateSignedBitcoinTx('deadbeef');

      expect(
        cubit.state.signedBitcoinTx,
        isNull,
        reason: 'a tampered transaction must never reach the broadcast path',
      );
      expect(cubit.state.failure, isA<SendTransactionConfirmationFailure>());
    });

    test('a signed transaction passing the output check is stored', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(hardwareSignReadyState());

      await cubit.updateSignedBitcoinTx('deadbeef');

      expect(cubit.state.signedBitcoinTx, 'deadbeef');
      expect(cubit.state.failure, isNull);
      verify(
        () => verifySignedTxUsecase.execute(
          unsignedPsbt: 'cHNidP8=',
          signedTransaction: 'deadbeef',
        ),
      ).called(1);
    });

    test('a valid retry clears the previous verification error', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(hardwareSignReadyState());
      var attempts = 0;
      when(
        () => verifySignedTxUsecase.execute(
          unsignedPsbt: any(named: 'unsignedPsbt'),
          signedTransaction: any(named: 'signedTransaction'),
        ),
      ).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) {
          return const Err<void, SendFailure>(
            SendTransactionConfirmationFailure(
              logMessage: 'The signed transaction does not match',
            ),
          );
        }
        return const Ok<void, SendFailure>(null);
      });

      expect(await cubit.updateSignedBitcoinTx('tampered'), isFalse);
      expect(cubit.state.failure, isA<SendTransactionConfirmationFailure>());

      expect(await cubit.updateSignedBitcoinTx('valid'), isTrue);
      expect(cubit.state.signedBitcoinTx, 'valid');
      expect(cubit.state.failure, isNull);
    });

    test(
      'a signed transaction with no unsigned PSBT in state is refused',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        cubit.setStateForTest(
          hardwareSignReadyState().copyWith(unsignedPsbt: null),
        );

        await cubit.updateSignedBitcoinTx('deadbeef');

        expect(cubit.state.signedBitcoinTx, isNull);
        expect(cubit.state.failure, isA<SendTransactionConfirmationFailure>());
        verifyNever(
          () => verifySignedTxUsecase.execute(
            unsignedPsbt: any(named: 'unsignedPsbt'),
            signedTransaction: any(named: 'signedTransaction'),
          ),
        );
      },
    );
  });

  group('SendCubit.onAmountConfirmed note handling', () {
    /// A Lightning send whose invoice carries a description. The description is
    /// the only record of what the payment was for, and the note is what ends
    /// up as a label on the sender's own transaction — so an empty note takes
    /// the description rather than dropping it. A note the user typed always
    /// wins over the description.
    SendState lightningReadyState({String label = ''}) => SendState(
      step: SendStep.confirm,
      sendType: SendType.lightning,
      selectedWallet: _bitcoinLocalWallet(),
      paymentRequest: const PaymentRequest.bolt11(
        invoice: 'lnbc1-invoice',
        amountSat: 50000,
        paymentHash: 'hash',
        description: 'Order 123456',
        expiresAt: 0,
        isTestnet: false,
      ),
      label: label,
    );

    /// Stops `onAmountConfirmed` right after the emit under test: the quote
    /// lookup is the next call and returning an error makes it bail out.
    void stubQuoteFailure() {
      when(
        () => getSendSwapQuoteUsecase.execute(
          wallet: any(named: 'wallet'),
          amountSat: any(named: 'amountSat'),
        ),
      ).thenAnswer((_) async => const Err(SendInvoiceExpiredFailure()));
    }

    test('an empty note is seeded with the invoice description', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      stubQuoteFailure();
      cubit.setStateForTest(lightningReadyState());

      await cubit.onAmountConfirmed();

      expect(cubit.state.lightningInvoice, isNotNull);
      expect(cubit.state.label, 'Order 123456');
    });

    test('a note the user typed overrides the invoice description', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      stubQuoteFailure();
      cubit.setStateForTest(lightningReadyState(label: 'coffee'));

      await cubit.onAmountConfirmed();

      expect(cubit.state.label, 'coffee');
    });

    test('surfaces a quote failure without creating a swap', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      stubQuoteFailure();
      cubit.setStateForTest(lightningReadyState());

      await cubit.onAmountConfirmed();

      expect(cubit.state.failure, isA<SendInvoiceExpiredFailure>());
      expect(cubit.state.creatingSwap, isFalse);
      expect(cubit.state.lightningOrder, isNull);
      verifyNever(
        () => createSendSwapUsecase.execute(
          walletId: 'w1',
          invoice: cubit.state.lightningInvoice!,
          amountSat: 50000,
          quote: null,
          note: 'Order 123456',
        ),
      );
    });
  });

  group('SendCubit.broadcastTransaction - BIP21 advertising pj without an '
      'attempted payjoin', () {
    SendState plainSignedState({String label = ''}) => SendState(
      step: SendStep.sending,
      sendType: SendType.bitcoin,
      selectedWallet: _bitcoinLocalWallet(),
      paymentRequest: _payjoinBip21(),
      payjoinGloballyEnabled: false,
      isToSelf: false,
      signedBitcoinPsbt: 'signed-psbt',
      label: label,
    );

    void stubBroadcast() {
      when(
        () => broadcastBitcoinTxUsecase.execute(
          any(),
          isPsbt: any(named: 'isPsbt'),
        ),
      ).thenAnswer((_) async => 'broadcast-txid');
    }

    test(
      'broadcasts the signed transaction and succeeds with its txid',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        stubBroadcast();
        cubit.setStateForTest(plainSignedState());

        await cubit.broadcastTransaction();

        verify(
          () => broadcastBitcoinTxUsecase.execute('signed-psbt', isPsbt: true),
        ).called(1);
        expect(cubit.state.txId, 'broadcast-txid');
        expect(cubit.state.step, SendStep.success);
        expect(cubit.state.failure, isNull);
      },
    );

    test('with a user label, stores the label on the broadcast txid', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      stubBroadcast();
      cubit.setStateForTest(plainSignedState(label: 'coffee'));

      await cubit.broadcastTransaction();

      verify(
        () => broadcastBitcoinTxUsecase.execute('signed-psbt', isPsbt: true),
      ).called(1);
      expect(cubit.state.txId, 'broadcast-txid');
      expect(cubit.state.step, SendStep.success);
      expect(cubit.state.failure, isNull);
      final stored =
          verify(() => labelsFacade.store(captureAny())).captured.single
              as NewLabel;
      expect(stored.reference, 'broadcast-txid');
      expect(stored.label, 'coffee');
    });
  });

  Wallet stubPaymentRequestContinuation() {
    final wallet = _bitcoinLocalWallet();
    when(
      () => getWalletUtxosUsecase.execute(walletId: wallet.id),
    ).thenAnswer((_) async => const []);
    when(
      () => watchFinishedWalletSyncsUsecase.execute(walletId: wallet.id),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => getNetworkFeesUsecase.execute(isLiquid: any(named: 'isLiquid')),
    ).thenAnswer((_) async => _sweepFeeOptions);
    return wallet;
  }

  test(
    'does not broadcast when a selected coin becomes unavailable during validation',
    () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      final selected = _utxo(amountSat: 10000);
      when(
        () => validateBitcoinSelectionUsecase.execute(
          walletId: 'w-bitcoin',
          selectedInputs: [selected],
        ),
      ).thenThrow(NoSpendableUtxoException('selected coin disappeared'));
      cubit.setStateForTest(
        SendState(
          step: SendStep.confirm,
          selectedWallet: _bitcoinWallet(balanceSat: 20000),
          selectedUtxos: [selected],
          unsignedPsbt: 'unsigned-psbt',
          signedBitcoinPsbt: 'signed-psbt',
        ),
      );

      await cubit.broadcastTransaction();

      expect(cubit.state.failure, isA<SendSelectedCoinsUnavailableFailure>());
      expect(cubit.state.unsignedPsbt, isNull);
      expect(cubit.state.signedBitcoinPsbt, isNull);
      verifyNever(
        () => broadcastBitcoinTxUsecase.execute(
          any(),
          isPsbt: any(named: 'isPsbt'),
        ),
      );
    },
  );

  group('SendCubit payment request input', () {
    test('stores sanitized input while parsing it', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      const parsed = PaymentRequest.lnAddress(address: 'user@example.com');
      when(
        () => detectBitcoinStringUsecase.execute(data: 'user@example.com'),
      ).thenAnswer((_) async => parsed);

      await cubit.onChangedText('  "user@example.com"  ');

      expect(cubit.state.copiedRawPaymentRequest, 'user@example.com');
      expect(cubit.state.paymentRequest, parsed);
      verify(
        () => detectBitcoinStringUsecase.execute(data: 'user@example.com'),
      ).called(1);
    });

    test('reports nothing while the address is still being typed', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      when(
        () => detectBitcoinStringUsecase.execute(data: any(named: 'data')),
      ).thenThrow(const FormatException('invalid'));

      // Every keystroke of a real address is an unparseable prefix. Reporting
      // the parse result here put "invalid address" on screen from the first
      // character; it belongs to Continue, against the finished input.
      for (final prefix in ['b', 'bc', 'bc1', 'bc1q']) {
        await cubit.onChangedText(prefix);
        expect(
          cubit.state.failure,
          isNull,
          reason: 'typing "$prefix" must not raise a failure yet',
        );
      }

      await cubit.continueOnAddressConfirmed();

      expect(cubit.state.failure, isA<SendInvalidPaymentRequestFailure>());
    });

    test('clears a Continue failure once the user edits the address', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      when(
        () => detectBitcoinStringUsecase.execute(data: any(named: 'data')),
      ).thenThrow(const FormatException('invalid'));

      await cubit.onChangedText('nonsense');
      await cubit.continueOnAddressConfirmed();
      expect(cubit.state.failure, isA<SendInvalidPaymentRequestFailure>());

      await cubit.onChangedText('nonsense2');

      expect(
        cubit.state.failure,
        isNull,
        reason: 'editing the field must dismiss the stale error',
      );
    });

    test('parses the current input when continuing', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      when(
        () => detectBitcoinStringUsecase.execute(data: 'invalid-address'),
      ).thenThrow(const FormatException('invalid'));

      cubit.onChangedText('invalid-address');
      await cubit.continueOnAddressConfirmed();

      verify(
        () => detectBitcoinStringUsecase.execute(data: 'invalid-address'),
      ).called(1);
      expect(cubit.state.paymentRequest, isNull);
      expect(cubit.state.failure, isA<SendInvalidPaymentRequestFailure>());
      expect(cubit.state.loadingBestWallet, isFalse);
    });

    test('waits for current input parsing before validating', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      final parsing = Completer<PaymentRequest>();
      when(
        () => detectBitcoinStringUsecase.execute(data: 'pending-address'),
      ).thenAnswer((_) => parsing.future);

      final input = cubit.onChangedText('pending-address');
      var submitCompleted = false;
      final submit = cubit.continueOnAddressConfirmed().whenComplete(
        () => submitCompleted = true,
      );
      await Future<void>.delayed(Duration.zero);

      try {
        expect(submitCompleted, isFalse);
      } finally {
        parsing.completeError(const FormatException('invalid'));
        await input;
        await submit;
      }
      expect(cubit.state.failure, isA<SendInvalidPaymentRequestFailure>());
      expect(cubit.state.loadingBestWallet, isFalse);
    });

    test('treats normalized empty input as clear', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      when(
        () => detectBitcoinStringUsecase.execute(data: ''),
      ).thenThrow(StateError('empty'));

      await cubit.onChangedText('  ""  ');

      expect(cubit.state.copiedRawPaymentRequest, isEmpty);
      expect(cubit.state.paymentRequest, isNull);
      expect(cubit.state.failure, isNull);
    });

    test(
      'continues with the Lightning alternative from a BIP21 request',
      () async {
        final wallet = _bitcoinLocalWallet();
        const request = PaymentRequest.bip21(
          network: Network.bitcoinMainnet,
          uri: 'bitcoin:bc1qfirst?lightning=lnbc1invoice',
          address: 'bc1qfirst',
          lightning: 'lnbc1invoice',
        );
        const invoice = PaymentRequest.bolt11(
          invoice: 'lnbc1invoice',
          amountSat: 0,
          paymentHash: 'hash',
          expiresAt: 2000000000,
          isTestnet: false,
        );
        when(
          () => bestWalletUsecase.execute(
            wallets: [wallet],
            request: invoice,
            amountSat: 0,
          ),
        ).thenReturn(Ok(wallet));
        when(
          () => getWalletUtxosUsecase.execute(walletId: wallet.id),
        ).thenAnswer((_) async => const []);
        when(
          () => watchFinishedWalletSyncsUsecase.execute(walletId: wallet.id),
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => getNetworkFeesUsecase.execute(isLiquid: any(named: 'isLiquid')),
        ).thenAnswer((_) async => _sweepFeeOptions);
        final cubit = buildCubit(parsePaymentRequest: (_) async => invoice);
        addTearDown(cubit.close);
        cubit.setStateForTest(
          SendState(wallets: [wallet], paymentRequest: request),
        );

        await cubit.continueOnAddressConfirmed();

        expect(cubit.state.paymentRequest, invoice);
        expect(cubit.state.sendType, SendType.lightning);
        expect(cubit.state.step, SendStep.amount);
        expect(cubit.state.loadingBestWallet, isFalse);
      },
    );

    test(
      'does not convert a payment detector StateError into input failure',
      () {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        when(
          () => detectBitcoinStringUsecase.execute(data: 'invalid-address'),
        ).thenThrow(StateError('detector state is invalid'));

        cubit.onChangedText('invalid-address');

        expectLater(cubit.continueOnAddressConfirmed(), throwsStateError);
      },
    );

    test('a scanner update clears stale MAX state outside a sweep', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        SendState(
          sendType: SendType.bitcoin,
          sendMax: true,
          recipientDrafts: const [
            (
              id: 0,
              address: 'bc1qold',
              amount: '',
              receivesRemainder: true,
              isValid: true,
            ),
          ],
        ),
      );
      when(
        () => detectBitcoinStringUsecase.execute(data: 'invalid-address'),
      ).thenThrow(const FormatException('invalid'));

      await cubit.onScannedPaymentRequest('invalid-address', null);

      expect(cubit.state.sendMax, isFalse);
      expect(cubit.state.hasRemainderRecipient, isFalse);
    });

    test(
      'keeps a newer valid submit result when an older one completes',
      () async {
        final cubit = buildCubit(wallet: stubPaymentRequestContinuation());
        addTearDown(cubit.close);
        final oldResult = Completer<PaymentRequest>();
        final newResult = Completer<PaymentRequest>();
        when(
          () => detectBitcoinStringUsecase.execute(data: any(named: 'data')),
        ).thenAnswer((invocation) {
          final data = invocation.namedArguments[#data] as String;
          return data == 'old-address' ? oldResult.future : newResult.future;
        });

        cubit.onChangedText('old-address');
        final oldSubmit = cubit.continueOnAddressConfirmed();
        cubit.onChangedText('new-address');
        final newSubmit = cubit.continueOnAddressConfirmed();
        newResult.complete(
          const PaymentRequest.lnAddress(address: 'new@example.com'),
        );
        await newSubmit;
        oldResult.complete(
          const PaymentRequest.bitcoin(address: 'old', isTestnet: true),
        );
        await oldSubmit;

        expect(cubit.state.copiedRawPaymentRequest, 'new-address');
        expect(
          cubit.state.paymentRequest,
          const PaymentRequest.lnAddress(address: 'new@example.com'),
        );
      },
    );

    test(
      'ignores an obsolete recipient result while keeping the current input',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        final oldParsing = Completer<PaymentRequest>();
        final newParsing = Completer<PaymentRequest>();
        when(
          () => detectBitcoinStringUsecase.execute(data: any(named: 'data')),
        ).thenAnswer((invocation) {
          final data = invocation.namedArguments[#data] as String;
          return data == 'old-address' ? oldParsing.future : newParsing.future;
        });
        cubit.setStateForTest(
          const SendState(
            copiedRawPaymentRequest: 'old-address',
            paymentRequest: PaymentRequest.bitcoin(
              address: 'old-address',
              isTestnet: true,
            ),
          ),
        );

        final oldFuture = cubit.onChangedText('old-address');
        final newFuture = cubit.onChangedText('new-address');
        expect(cubit.state.copiedRawPaymentRequest, 'new-address');
        expect(cubit.state.paymentRequest, isNull);

        oldParsing.complete(
          const PaymentRequest.bitcoin(address: 'old', isTestnet: true),
        );
        await oldFuture;
        expect(cubit.state.paymentRequest, isNull);

        newParsing.complete(
          const PaymentRequest.lnAddress(address: 'new@example.com'),
        );
        await newFuture;

        expect(
          cubit.state.paymentRequest,
          const PaymentRequest.lnAddress(address: 'new@example.com'),
        );
        verify(
          () => detectBitcoinStringUsecase.execute(data: 'old-address'),
        ).called(1);
        verify(
          () => detectBitcoinStringUsecase.execute(data: 'new-address'),
        ).called(1);
      },
    );

    test('keeps a newer valid result when an older parse fails', () async {
      final cubit = buildCubit(wallet: stubPaymentRequestContinuation());
      addTearDown(cubit.close);
      final oldResult = Completer<PaymentRequest>();
      final newResult = Completer<PaymentRequest>();
      when(
        () => detectBitcoinStringUsecase.execute(data: any(named: 'data')),
      ).thenAnswer((invocation) {
        final data = invocation.namedArguments[#data] as String;
        return data == 'old-address' ? oldResult.future : newResult.future;
      });

      cubit.onChangedText('old-address');
      final oldSubmit = cubit.continueOnAddressConfirmed();
      cubit.onChangedText('new-address');
      final newSubmit = cubit.continueOnAddressConfirmed();
      newResult.complete(
        const PaymentRequest.lnAddress(address: 'new@example.com'),
      );
      await newSubmit;
      oldResult.completeError(const FormatException('old input is invalid'));
      await oldSubmit;

      expect(
        cubit.state.paymentRequest,
        const PaymentRequest.lnAddress(address: 'new@example.com'),
      );
    });

    test(
      'stops an obsolete continuation resumed after wallet utxos load',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        final wallet = _bitcoinWallet(balanceSat: 100000);
        final oldUtxosLoaded = Completer<List<WalletUtxo>>();
        const oldRequest = PaymentRequest.bitcoin(
          address: 'old-address',
          isTestnet: false,
        );
        const newRequest = PaymentRequest.lnAddress(address: 'new@example.com');

        when(
          () => bestWalletUsecase.execute(
            wallets: any(named: 'wallets'),
            request: any(named: 'request'),
            amountSat: any(named: 'amountSat'),
          ),
        ).thenReturn(Ok<Wallet, SendFailure>(wallet));
        when(
          () => getWalletUtxosUsecase.execute(walletId: wallet.id),
        ).thenAnswer((_) => oldUtxosLoaded.future);
        when(
          () => checkLiquidConsolidationUsecase.execute(walletId: wallet.id),
        ).thenAnswer((_) async => false);
        when(
          () => getNetworkFeesUsecase.execute(isLiquid: any(named: 'isLiquid')),
        ).thenAnswer((_) async => _feeOptions());
        when(
          () => watchFinishedWalletSyncsUsecase.execute(walletId: wallet.id),
        ).thenAnswer((_) => const Stream<Wallet>.empty());

        final oldContinuation = cubit.onScannedPaymentRequest(
          'old-address',
          oldRequest,
        );
        await untilCalled(
          () => getWalletUtxosUsecase.execute(walletId: wallet.id),
        );
        verify(
          () => getWalletUtxosUsecase.execute(walletId: wallet.id),
        ).called(1);

        final newContinuation = cubit.onScannedPaymentRequest(
          'new@example.com',
          newRequest,
        );
        await newContinuation;
        expect(cubit.state.sendType, SendType.lightning);

        oldUtxosLoaded.complete(const <WalletUtxo>[]);
        await oldContinuation;

        expect(
          cubit.state.sendType,
          SendType.lightning,
          reason:
              'an obsolete continuation must not overwrite the current send type',
        );
        verify(
          () => getNetworkFeesUsecase.execute(isLiquid: any(named: 'isLiquid')),
        ).called(2);
      },
    );

    test('stops an obsolete continuation resumed after fees load', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      final wallet = _bitcoinWallet(balanceSat: 100000);
      final oldBitcoinFeesLoaded = Completer<FeeOptions>();
      const oldRequest = PaymentRequest.bitcoin(
        address: 'old-address',
        isTestnet: false,
      );
      const newRequest = PaymentRequest.lnAddress(address: 'new@example.com');

      when(
        () => bestWalletUsecase.execute(
          wallets: any(named: 'wallets'),
          request: any(named: 'request'),
          amountSat: any(named: 'amountSat'),
        ),
      ).thenReturn(Ok<Wallet, SendFailure>(wallet));
      when(
        () => getWalletUtxosUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) async => const <WalletUtxo>[]);
      when(
        () => checkLiquidConsolidationUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) async => false);
      when(
        () => getNetworkFeesUsecase.execute(isLiquid: false),
      ).thenAnswer((_) => oldBitcoinFeesLoaded.future);
      when(
        () => getNetworkFeesUsecase.execute(isLiquid: true),
      ).thenAnswer((_) async => _feeOptions());
      when(
        () => watchFinishedWalletSyncsUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) => const Stream<Wallet>.empty());
      when(
        () => detectBitcoinStringUsecase.execute(data: 'new@example.com'),
      ).thenAnswer((_) async => newRequest);

      final oldContinuation = cubit.onScannedPaymentRequest(
        'old-address',
        oldRequest,
      );
      await untilCalled(() => getNetworkFeesUsecase.execute(isLiquid: false));

      await cubit.onChangedText('new@example.com');
      expect(cubit.state.step, SendStep.address);

      oldBitcoinFeesLoaded.complete(_feeOptions());
      await oldContinuation;

      expect(cubit.state.paymentRequest, newRequest);
      expect(
        cubit.state.step,
        SendStep.address,
        reason: 'an obsolete continuation must not advance the current input',
      );
    });

    test('uses a scanned payment request without reparsing it', () async {
      const request = PaymentRequest.lnAddress(address: 'user@example.com');
      final cubit = buildCubit(wallet: stubPaymentRequestContinuation());
      addTearDown(cubit.close);

      // The scanner already supplied the parsed request; this assertion only
      // covers the input boundary before the remainder of the flow runs.
      await cubit.onScannedPaymentRequest('  user@example.com  ', request);

      expect(cubit.state.copiedRawPaymentRequest, 'user@example.com');
      expect(cubit.state.paymentRequest, request);
      verifyNever(
        () => detectBitcoinStringUsecase.execute(data: any(named: 'data')),
      );
    });
  });

  group('SendCubit.loadUtxos', () {
    test(
      'drops a missing selected coin and invalidates its transaction',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        final selected = _utxo(amountSat: 10000);
        when(
          () => getWalletUtxosUsecase.execute(walletId: 'w-bitcoin'),
        ).thenAnswer((_) async => const <WalletUtxo>[]);
        cubit.setStateForTest(
          SendState(
            selectedWallet: _bitcoinWallet(balanceSat: 20000),
            utxos: [selected],
            selectedUtxos: [selected],
            unsignedPsbt: 'unsigned-psbt',
            signedBitcoinPsbt: 'signed-psbt',
          ),
        );

        await cubit.loadUtxos();

        expect(cubit.state.utxos, isEmpty);
        expect(cubit.state.selectedUtxos, isEmpty);
        expect(cubit.state.failure, isA<SendSelectedCoinsUnavailableFailure>());
        expect(cubit.state.unsignedPsbt, isNull);
        expect(cubit.state.signedBitcoinPsbt, isNull);
      },
    );
  });

  // A shortfall used to show "Build Failed", the same message as a dead
  // Electrum server or a bad address.
  group('SendCubit.createTransaction shortfalls', () {
    test(
      'a selected coin that disappears is unavailable, not insufficient',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        final selected = _utxo(amountSat: 10000);
        when(
          () => prepareBitcoinSendUsecase.execute(
            walletId: any(named: 'walletId'),
            recipients: any(named: 'recipients'),
            networkFee: any(named: 'networkFee'),
            selectedInputs: any(named: 'selectedInputs'),
            replaceByFee: any(named: 'replaceByFee'),
          ),
        ).thenThrow(NoSpendableUtxoException('selected coin disappeared'));
        when(
          () => getWalletUtxosUsecase.execute(walletId: any(named: 'walletId')),
        ).thenAnswer((_) async => [selected]);
        cubit.setStateForTest(
          SendState(
            step: SendStep.amount,
            sendType: SendType.bitcoin,
            selectedWallet: _bitcoinWallet(balanceSat: 20000),
            paymentRequest: const PaymentRequest.bitcoin(
              address: 'bc1-address',
              isTestnet: false,
            ),
            amount: '5000',
            confirmedAmountSat: 5000,
            inputAmountCurrencyCode: 'sats',
            bitcoinFeesList: _feeOptions(),
            liquidFeesList: _feeOptions(),
            selectedUtxos: [selected],
          ),
        );

        when(
          () => getWalletUtxosUsecase.execute(walletId: any(named: 'walletId')),
        ).thenAnswer((_) async => [selected]);
        when(
          () => checkLiquidConsolidationUsecase.execute(
            walletId: any(named: 'walletId'),
          ),
        ).thenAnswer((_) async => false);

        await cubit.createTransaction();

        expect(cubit.state.failure, isA<SendSelectedCoinsUnavailableFailure>());
        expect(
          cubit.state.failure,
          isNot(isA<SendSelectedCoinsInsufficientFailure>()),
        );
      },
    );

    test(
      'a shortfall at build time is an insufficient-balance failure',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        when(
          () => prepareLiquidSendUsecase.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
            feeRate: any(named: 'feeRate'),
            amountSat: any(named: 'amountSat'),
            drain: any(named: 'drain'),
          ),
        ).thenThrow(
          InsufficientFundsException(
            'InsufficientFunds { missing_sats: 2, is_token: false }',
          ),
        );
        when(
          () => getWalletUtxosUsecase.execute(walletId: any(named: 'walletId')),
        ).thenAnswer((_) async => <WalletUtxo>[]);
        cubit.setStateForTest(
          SendState(
            step: SendStep.amount,
            sendType: SendType.liquid,
            selectedWallet: _liquidWallet(balanceSat: 20000),
            paymentRequest: const PaymentRequest.liquid(
              address: 'lq1-address',
              isTestnet: false,
            ),
            amount: '19998',
            inputAmountCurrencyCode: 'sats',
            liquidFeesList: _feeOptions(),
            bitcoinFeesList: _feeOptions(),
          ),
        );

        when(
          () => checkLiquidConsolidationUsecase.execute(
            walletId: any(named: 'walletId'),
          ),
        ).thenAnswer((_) async => false);

        await cubit.createTransaction();

        expect(cubit.state.failure, isA<SendInsufficientFundsForFeesFailure>());
        expect(cubit.state.failure, isNot(isA<SendTransactionBuildFailure>()));
        // and it must not move on to confirm with no transaction built
        expect(cubit.state.step, SendStep.amount);
      },
    );

    // With hand-picked coins the amount was only checked against the whole
    // balance, so the shortfall may be the selection rather than the fee.
    test(
      'with hand-picked coins the message identifies selection shortfall',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        when(
          () => prepareBitcoinSendUsecase.execute(
            walletId: any(named: 'walletId'),
            recipients: any(named: 'recipients'),
            networkFee: any(named: 'networkFee'),
            selectedInputs: any(named: 'selectedInputs'),
            replaceByFee: any(named: 'replaceByFee'),
          ),
        ).thenThrow(InsufficientFundsException('needed 5000, available 1000'));
        final selected = _utxo(amountSat: 1000);
        // loadUtxos() filters the selection against the wallet's current UTXOs,
        // so the picked coin has to be in the list or the selection is dropped.
        when(
          () => getWalletUtxosUsecase.execute(walletId: any(named: 'walletId')),
        ).thenAnswer((_) async => [selected]);
        cubit.setStateForTest(
          SendState(
            step: SendStep.amount,
            sendType: SendType.bitcoin,
            selectedWallet: _bitcoinWallet(balanceSat: 20000),
            paymentRequest: const PaymentRequest.bitcoin(
              address: 'bc1-address',
              isTestnet: false,
            ),
            amount: '5000',
            confirmedAmountSat: 5000,
            inputAmountCurrencyCode: 'sats',
            liquidFeesList: _feeOptions(),
            bitcoinFeesList: _feeOptions(),
            selectedUtxos: [selected],
          ),
        );

        await cubit.createTransaction();

        expect(
          cubit.state.failure,
          isA<SendSelectedCoinsInsufficientFailure>(),
        );
        expect(
          cubit.state.failure,
          isNot(isA<SendInsufficientFundsForFeesFailure>()),
        );
        final captured = verify(
          () => prepareBitcoinSendUsecase.execute(
            walletId: any(named: 'walletId'),
            recipients: captureAny(named: 'recipients'),
            networkFee: any(named: 'networkFee'),
            selectedInputs: captureAny(named: 'selectedInputs'),
            replaceByFee: any(named: 'replaceByFee'),
          ),
        ).captured;
        final recipients = captured[0] as List<BitcoinTransactionRecipient>;
        expect(recipients.single.amountSat, Sats.fromInt(5000));
        expect(captured[1] as List<WalletUtxo>, [selected]);
      },
    );

    // #2337: frozen coins cause a shortfall too, and only the generic failure
    // reaches the "manage coins" hint that tells the user what to do.
    test('with frozen coins the message stays generic', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      when(
        () => prepareBitcoinSendUsecase.execute(
          walletId: any(named: 'walletId'),
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          selectedInputs: any(named: 'selectedInputs'),
          replaceByFee: any(named: 'replaceByFee'),
        ),
      ).thenThrow(InsufficientFundsException('needed 10000, available 5000'));
      when(
        () => getWalletUtxosUsecase.execute(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => [_utxo(amountSat: 15000, isFrozen: true)]);
      cubit.setStateForTest(
        SendState(
          step: SendStep.amount,
          sendType: SendType.bitcoin,
          selectedWallet: _bitcoinWallet(balanceSat: 20000),
          paymentRequest: const PaymentRequest.bitcoin(
            address: 'bc1-address',
            isTestnet: false,
          ),
          // Fits the 20000 balance, but 15000 of it is frozen.
          amount: '10000',
          inputAmountCurrencyCode: 'sats',
          liquidFeesList: _feeOptions(),
          bitcoinFeesList: _feeOptions(),
        ),
      );

      await cubit.onAmountConfirmed();

      expect(cubit.state.frozenBalanceSat, 15000);
      expect(cubit.state.failure, isA<SendInsufficientBalanceFailure>());
      expect(
        cubit.state.failure,
        isNot(isA<SendInsufficientFundsForFeesFailure>()),
      );
    });
  });
}
