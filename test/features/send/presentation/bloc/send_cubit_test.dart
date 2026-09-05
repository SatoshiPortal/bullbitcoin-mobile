import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/insufficient_funds_exception.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
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
import 'package:bb_mobile/features/send/domain/pending_bitcoin_transaction.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_pset_size_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_cross_chain_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_cross_chain_quote_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_swap_quote_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/apply_bitcoin_policy_preimages_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_bitcoin_signing_plan_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/process_bitcoin_signer_result_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/resolve_bitcoin_policy_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/restore_pending_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/resolve_lightning_address_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/select_best_wallet_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/update_paid_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/verify_exchange_payin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/update_send_swap_payin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/validate_bitcoin_policy_preimage_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/delete_pending_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_pending_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/save_pending_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/validate_pending_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Sats;

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

class _MockValidateBitcoinSelectionUsecase extends Mock
    implements ValidateBitcoinSelectionUsecase {}

class _MockPrepareLiquidSendUsecase extends Mock
    implements PrepareLiquidSendUsecase {}

class _MockSendWithPayjoinUsecase extends Mock
    implements SendWithPayjoinUsecase {}

class _MockWatchPayjoinUsecase extends Mock implements WatchPayjoinUsecase {}

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

class _MockUpdatePaidSendSwapUsecase extends Mock
    implements UpdatePaidSendSwapUsecase {}

class _MockWatchFinishedWalletSyncsUsecase extends Mock
    implements WatchFinishedWalletSyncsUsecase {}

class _MockSignBitcoinTxUsecase extends Mock implements SignBitcoinTxUsecase {}

class _MockGetBitcoinSigningPlanUsecase extends Mock
    implements GetBitcoinSigningPlanUsecase {}

class _MockValidateBitcoinPolicyPreimageUsecase extends Mock
    implements ValidateBitcoinPolicyPreimageUsecase {}

class _MockApplyBitcoinPolicyPreimagesUsecase extends Mock
    implements ApplyBitcoinPolicyPreimagesUsecase {}

class _MockProcessBitcoinSignerResultUsecase extends Mock
    implements ProcessBitcoinSignerResultUsecase {}

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

class _MockSavePendingBitcoinTransactionUsecase extends Mock
    implements SavePendingBitcoinTransactionUsecase {}

class _MockGetPendingBitcoinTransactionUsecase extends Mock
    implements GetPendingBitcoinTransactionUsecase {}

class _MockDeletePendingBitcoinTransactionUsecase extends Mock
    implements DeletePendingBitcoinTransactionUsecase {}

class _MockValidatePendingBitcoinTransactionUsecase extends Mock
    implements ValidatePendingBitcoinTransactionUsecase {}

class _MockRestorePendingBitcoinTransactionUsecase extends Mock
    implements RestorePendingBitcoinTransactionUsecase {}

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
    required super.getBitcoinSigningPlanUsecase,
    required super.resolveBitcoinPolicyUsecase,
    required super.validateBitcoinPolicyPreimageUsecase,
    required super.applyBitcoinPolicyPreimagesUsecase,
    required super.processBitcoinSignerResultUsecase,
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
    required super.savePendingBitcoinTransactionUsecase,
    required super.getPendingBitcoinTransactionUsecase,
    required super.restorePendingBitcoinTransactionUsecase,
    required super.deletePendingBitcoinTransactionUsecase,
    required super.validatePendingBitcoinTransactionUsecase,
    super.parsePaymentRequest,
  });

  void setStateForTest(SendState state) => emit(state);
}

Wallet _bitcoinLocalWallet() => Wallet(
  origin: 'w1',
  network: Network.bitcoinMainnet,
  signers: [
    WalletSigner.single(
      masterFingerprint: '',
      xpubFingerprint: '00000000',
      xpub: '',
      derivationPath: "m/84'/0'/0'",
      descriptorPath: standardSingleSignatureDescriptorPath,
      signer: SignerEntity.local,
      signerDevice: null,
    ),
  ],
  scriptType: ScriptType.bip84,
  publicDescriptor: 'wpkh(xpub/<0;1>/*)',
  balanceSat: BigInt.from(1000000),
);

Wallet _descriptorWallet() => Wallet(
  origin: 'descriptor-wallet',
  network: Network.bitcoinMainnet,
  signers: [
    WalletSigner.single(
      masterFingerprint: '11111111',
      xpubFingerprint: '11111111',
      xpub: 'xpub',
      descriptorPath: '/0/*',
      signer: SignerEntity.remote,
      signerDevice: null,
    ),
  ],
  scriptType: null,
  publicDescriptor: 'wsh(pk(xpub/0/*))',
  balanceSat: BigInt.from(1000000),
);

Wallet _liquidWallet({required int balanceSat}) => Wallet(
  origin: 'w-liquid',
  network: Network.liquidMainnet,
  signers: [
    WalletSigner.single(
      masterFingerprint: '',
      xpubFingerprint: '00000000',
      xpub: '',
      signer: SignerEntity.local,
      signerDevice: null,
    ),
  ],
  scriptType: ScriptType.bip84,
  publicDescriptor: '',
  balanceSat: BigInt.from(balanceSat),
);

Wallet _bitcoinWallet({required int balanceSat}) => Wallet(
  origin: 'w-bitcoin',
  network: Network.bitcoinMainnet,
  signers: [
    WalletSigner.single(
      masterFingerprint: '',
      xpubFingerprint: '00000000',
      xpub: '',
      signer: SignerEntity.local,
      signerDevice: null,
    ),
  ],
  scriptType: ScriptType.bip84,
  publicDescriptor: '',
  balanceSat: BigInt.from(balanceSat),
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

BitcoinWalletPolicy _mandatoryRelativeTimelockPolicy() {
  BitcoinSpendingPolicy spendingPolicy() => BitcoinSpendingPolicy(
    root: BitcoinThresholdPolicyNode(
      id: 'root',
      threshold: 2,
      children: [
        BitcoinSignaturePolicyNode(
          id: 'signature',
          key: BitcoinPolicyKey(
            kind: BitcoinPolicyKeyKind.fingerprint,
            value: '00000000',
          ),
        ),
        BitcoinRelativeTimelockPolicyNode(id: 'relative', value: 10),
      ],
    ),
    requiresPath: false,
  );

  return BitcoinWalletPolicy(
    external: spendingPolicy(),
    internal: spendingPolicy(),
  );
}

BitcoinWalletPolicy _singleSignaturePolicy() {
  final spendingPolicy = BitcoinSpendingPolicy(
    root: BitcoinSignaturePolicyNode(
      id: 'signature',
      key: BitcoinPolicyKey(
        kind: BitcoinPolicyKeyKind.fingerprint,
        value: '00000000',
      ),
    ),
    requiresPath: false,
  );
  return BitcoinWalletPolicy(
    external: spendingPolicy,
    internal: spendingPolicy,
  );
}

BitcoinWalletPolicy _mandatoryHashlockPolicy() {
  BitcoinSpendingPolicy spendingPolicy() => BitcoinSpendingPolicy(
    root: BitcoinThresholdPolicyNode(
      id: 'root',
      threshold: 2,
      children: [
        BitcoinSignaturePolicyNode(
          id: 'signature',
          key: BitcoinPolicyKey(
            kind: BitcoinPolicyKeyKind.fingerprint,
            value: '00000000',
          ),
        ),
        BitcoinHashlockPolicyNode(
          id: 'hashlock',
          type: BitcoinHashlockType.sha256,
          hash: List.filled(32, '11').join(),
        ),
      ],
    ),
    requiresPath: false,
  );

  return BitcoinWalletPolicy(
    external: spendingPolicy(),
    internal: spendingPolicy(),
  );
}

BitcoinWalletPolicy _selectableThresholdPolicy(List<WalletSigner> signers) {
  String fingerprint(WalletSigner signer) =>
      signer.descriptorKeys.single.masterFingerprint.isNotEmpty
      ? signer.descriptorKeys.single.masterFingerprint
      : signer.descriptorKeys.single.xpubFingerprint;

  BitcoinSpendingPolicy spendingPolicy() => BitcoinSpendingPolicy(
    root: BitcoinThresholdPolicyNode(
      id: 'root',
      threshold: 2,
      requiresPath: true,
      children: [
        for (final signer in signers)
          BitcoinSignaturePolicyNode(
            id: fingerprint(signer),
            key: BitcoinPolicyKey(
              kind: BitcoinPolicyKeyKind.fingerprint,
              value: fingerprint(signer),
            ),
          ),
      ],
    ),
    requiresPath: true,
  );

  return BitcoinWalletPolicy(
    external: spendingPolicy(),
    internal: spendingPolicy(),
  );
}

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
  late _MockGetBitcoinSigningPlanUsecase getBitcoinSigningPlanUsecase;
  late _MockValidateBitcoinPolicyPreimageUsecase
  validateBitcoinPolicyPreimageUsecase;
  late _MockApplyBitcoinPolicyPreimagesUsecase
  applyBitcoinPolicyPreimagesUsecase;
  late _MockProcessBitcoinSignerResultUsecase processBitcoinSignerResultUsecase;
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
  late _MockSavePendingBitcoinTransactionUsecase
  savePendingBitcoinTransactionUsecase;
  late _MockGetPendingBitcoinTransactionUsecase
  getPendingBitcoinTransactionUsecase;
  late _MockDeletePendingBitcoinTransactionUsecase
  deletePendingBitcoinTransactionUsecase;
  late _MockValidatePendingBitcoinTransactionUsecase
  validatePendingBitcoinTransactionUsecase;

  late StreamController<PayjoinSession> payjoinEvents;

  _TestableSendCubit buildCubit({
    Wallet? wallet,
    Future<PaymentRequest> Function(String)? parsePaymentRequest,
    RestorePendingBitcoinTransactionUsecase? restorePendingTransactionUsecase,
  }) => _TestableSendCubit(
    wallet: wallet,
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
    getBitcoinSigningPlanUsecase: getBitcoinSigningPlanUsecase,
    resolveBitcoinPolicyUsecase: ResolveBitcoinPolicyUsecase(
      getBitcoinSigningPlanUsecase,
    ),
    validateBitcoinPolicyPreimageUsecase: validateBitcoinPolicyPreimageUsecase,
    applyBitcoinPolicyPreimagesUsecase: applyBitcoinPolicyPreimagesUsecase,
    processBitcoinSignerResultUsecase: processBitcoinSignerResultUsecase,
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
    savePendingBitcoinTransactionUsecase: savePendingBitcoinTransactionUsecase,
    getPendingBitcoinTransactionUsecase: getPendingBitcoinTransactionUsecase,
    restorePendingBitcoinTransactionUsecase:
        restorePendingTransactionUsecase ??
        RestorePendingBitcoinTransactionUsecase(
          getPendingBitcoinTransactionUsecase,
          getWalletUsecase,
          getWalletUtxosUsecase,
          detectBitcoinStringUsecase,
          validatePendingBitcoinTransactionUsecase,
          getBitcoinSigningPlanUsecase,
          calculateBitcoinAbsoluteFeesUsecase,
          convertSatsUsecase,
        ),
    deletePendingBitcoinTransactionUsecase:
        deletePendingBitcoinTransactionUsecase,
    validatePendingBitcoinTransactionUsecase:
        validatePendingBitcoinTransactionUsecase,
    parsePaymentRequest: parsePaymentRequest,
  );

  void stubSingleSignaturePolicy(Wallet wallet) {
    final plan = BitcoinSigningPlan.fromPolicy(
      policy: _singleSignaturePolicy(),
      signers: wallet.signers,
    );
    when(
      () => getBitcoinSigningPlanUsecase.execute(
        wallet: wallet,
        selection: const BitcoinPolicySelection.empty(),
      ),
    ).thenAnswer(
      (_) async => Ok((
        plan: plan,
        maturity: const BitcoinPolicyMaturity.empty(),
        review: null,
      )),
    );
  }

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
    registerFallbackValue(
      PendingBitcoinTransaction(
        id: 'fallback',
        walletId: 'fallback-wallet',
        stage: PendingBitcoinTransactionStage.draft,
        recipient: '',
        amount: '',
        amountCurrencyCode: '',
        sendMax: false,
        feeSelection: FeeSelection.fastest,
        replaceByFee: true,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    registerFallbackValue(_bitcoinLocalWallet());
    registerFallbackValue(BigInt.zero);
    registerFallbackValue(
      const PaymentRequest.bitcoin(address: 'fallback', isTestnet: true),
    );
    // For any(named: 'feeRate') on the prepare-send stubs.
    registerFallbackValue(NetworkFee.relativeFromSatPerVbyte(1));
    registerFallbackValue(
      BitcoinPolicyPath(
        external: const {},
        internal: const {},
        requiresRelativeTimelock: false,
      ),
    );
    registerFallbackValue(<BitcoinPolicyPreimage>[]);
    registerFallbackValue(const BitcoinPolicySelection.empty());
    registerFallbackValue(<String>{});
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
    getBitcoinSigningPlanUsecase = _MockGetBitcoinSigningPlanUsecase();
    validateBitcoinPolicyPreimageUsecase =
        _MockValidateBitcoinPolicyPreimageUsecase();
    applyBitcoinPolicyPreimagesUsecase =
        _MockApplyBitcoinPolicyPreimagesUsecase();
    processBitcoinSignerResultUsecase =
        _MockProcessBitcoinSignerResultUsecase();
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
    savePendingBitcoinTransactionUsecase =
        _MockSavePendingBitcoinTransactionUsecase();
    getPendingBitcoinTransactionUsecase =
        _MockGetPendingBitcoinTransactionUsecase();
    deletePendingBitcoinTransactionUsecase =
        _MockDeletePendingBitcoinTransactionUsecase();
    validatePendingBitcoinTransactionUsecase =
        _MockValidatePendingBitcoinTransactionUsecase();
    payjoinEvents = StreamController<PayjoinSession>.broadcast();

    // Benign default stubs for everything the payjoin branch (or its
    // aftermath) touches.
    when(() => watchPayjoinUsecase.execute(ids: any(named: 'ids'))).thenAnswer(
      (_) => payjoinEvents.stream.map(Ok<PayjoinSession, SendFailure>.new),
    );
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

  group('SendCubit resumable Bitcoin transactions', () {
    test('keeps descriptor wallets available for Send', () async {
      final descriptorWallet = _descriptorWallet();
      when(
        () => getWalletsUsecase.execute(),
      ).thenAnswer((_) async => [descriptorWallet]);
      when(
        () => getAvailableCurrenciesUsecase.execute(),
      ).thenAnswer((_) async => []);
      when(() => getSettingsUsecase.execute()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      );
      when(
        () => getSendPayjoinEnabledUsecase.execute(),
      ).thenAnswer((_) async => false);
      when(
        () => convertSatsUsecase.execute(
          currencyCode: any(named: 'currencyCode'),
        ),
      ).thenAnswer((_) async => 1);
      when(() => convertSatsUsecase.execute()).thenAnswer((_) async => 1);
      when(
        () => getNetworkFeesUsecase.execute(isLiquid: any(named: 'isLiquid')),
      ).thenAnswer((_) async => _feeOptions());
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.loadWalletWithRatesAndFees();

      expect(cubit.state.wallets, [descriptorWallet]);
    });

    test('requires recipient input and uses the preselected wallet', () async {
      final wallet = _bitcoinLocalWallet();
      final cubit = buildCubit(wallet: wallet);
      addTearDown(cubit.close);
      late PendingBitcoinTransaction saved;
      when(
        () => savePendingBitcoinTransactionUsecase.execute(
          any(),
          expectedRevision: any(named: 'expectedRevision'),
        ),
      ).thenAnswer((invocation) async {
        saved =
            invocation.positionalArguments.single as PendingBitcoinTransaction;
        return Ok(saved);
      });

      expect(await cubit.saveDraft(), isFalse);
      verifyNever(
        () => savePendingBitcoinTransactionUsecase.execute(
          any(),
          expectedRevision: any(named: 'expectedRevision'),
        ),
      );

      cubit.setStateForTest(
        cubit.state.copyWith(copiedRawPaymentRequest: 'bc1qincomplete'),
      );
      expect(await cubit.saveDraft(), isTrue);

      expect(saved.walletId, wallet.id);
      expect(cubit.state.selectedWallet, wallet);
    });

    test('reopens a saved draft with incomplete recipient text', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      final wallet = _bitcoinLocalWallet();
      final stored = PendingBitcoinTransaction(
        id: 'draft-id',
        walletId: wallet.id,
        stage: PendingBitcoinTransactionStage.draft,
        label: 'August payment',
        recipient: 'bc1qincomplete',
        amount: '12.50',
        amountCurrencyCode: 'USD',
        sendMax: true,
        feeSelection: FeeSelection.custom,
        customFee: NetworkFee.relativeFromSatPerVbyte(3),
        replaceByFee: false,
        payjoinOptedOut: true,
        createdAt: DateTime.utc(2026, 8, 14),
        updatedAt: DateTime.utc(2026, 8, 14),
      );
      when(
        () => getPendingBitcoinTransactionUsecase.execute(stored.id),
      ).thenAnswer((_) async => Ok(stored));
      when(
        () => detectBitcoinStringUsecase.execute(data: stored.recipient),
      ).thenThrow('Invalid payment request');
      when(
        () => convertSatsUsecase.execute(currencyCode: 'USD'),
      ).thenAnswer((_) async => 1.25);
      when(
        () => getWalletUtxosUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) async => []);
      when(
        () => watchFinishedWalletSyncsUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) => const Stream.empty());
      cubit.setStateForTest(
        SendState(
          wallets: [wallet],
          isSigningSession: true,
          isSigningConflict: true,
          signedBitcoinTx: 'previous-transaction',
          signedBitcoinPsbt: 'previous-psbt',
        ),
      );

      expect(await cubit.loadPendingTransaction(stored.id), isTrue);
      expect(cubit.state.isSigningSession, isFalse);
      expect(cubit.state.isSigningConflict, isFalse);
      expect(cubit.state.signedBitcoinTx, isNull);
      expect(cubit.state.signedBitcoinPsbt, isNull);
      when(
        () => savePendingBitcoinTransactionUsecase.execute(
          any(),
          expectedRevision: any(named: 'expectedRevision'),
        ),
      ).thenAnswer(
        (invocation) async => Ok(
          invocation.positionalArguments.single as PendingBitcoinTransaction,
        ),
      );
      cubit.markDraftChanged();
      expect(cubit.state.hasUnsavedDraftChanges, isTrue);

      expect(cubit.state.pendingTransactionId, stored.id);
      expect(cubit.state.isDraftSaved, isTrue);
      expect(cubit.state.copiedRawPaymentRequest, stored.recipient);
      expect(cubit.state.paymentRequest, isNull);
      expect(cubit.state.amount, stored.amount);
      expect(cubit.state.inputAmountCurrencyCode, stored.amountCurrencyCode);
      expect(cubit.state.fiatCurrencyCode, 'USD');
      expect(cubit.state.exchangeRate, 1.25);
      expect(cubit.state.sendMax, isTrue);
      expect(cubit.state.selectedFeeOption, FeeSelection.custom);
      expect(cubit.state.customFee, stored.customFee);
      expect(cubit.state.replaceByFee, isFalse);
      expect(cubit.state.payjoinOptedOut, isTrue);
      expect(cubit.state.sendType, SendType.bitcoin);
      expect(cubit.state.step, SendStep.address);
    });

    test(
      'does not emit when pending restoration finishes after close',
      () async {
        final restore = _MockRestorePendingBitcoinTransactionUsecase();
        final pending =
            Completer<Result<RestoredPendingBitcoinTransaction, SendFailure>>();
        when(
          () => restore.execute('draft-id'),
        ).thenAnswer((_) => pending.future);
        final cubit = buildCubit(restorePendingTransactionUsecase: restore);

        final loading = cubit.loadPendingTransaction('draft-id');
        await pumpEventQueue();
        await cubit.close();
        pending.complete(const Err(SendStoredTransactionInvalidFailure()));

        expect(await loading, isFalse);
      },
    );

    test('keeps a resumed draft wallet after address confirmation', () async {
      final wallet = _bitcoinLocalWallet();
      final otherWallet = wallet.copyWith(origin: 'other-wallet');
      const request = PaymentRequest.bitcoin(
        address: 'bc1qrecipient',
        isTestnet: false,
      );
      final fees = FeeOptions(
        fastest: NetworkFee.relativeFromSatPerVbyte(2),
        economic: NetworkFee.relativeFromSatPerVbyte(1),
        slow: NetworkFee.relativeFromSatPerVbyte(0.5),
        minRelay: NetworkFee.relativeFromSatPerVbyte(0.1),
      );
      when(
        () => bestWalletUsecase.execute(
          wallets: [wallet, otherWallet],
          request: request,
          amountSat: null,
        ),
      ).thenReturn(Ok<Wallet, SendFailure>(otherWallet));
      when(
        () => watchFinishedWalletSyncsUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => getNetworkFeesUsecase.execute(isLiquid: any(named: 'isLiquid')),
      ).thenAnswer((_) async => fees);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        SendState(
          wallets: [wallet, otherWallet],
          selectedWallet: wallet,
          isWalletManuallySelected: true,
          paymentRequest: request,
        ),
      );

      await cubit.continueOnAddressConfirmed();

      expect(cubit.state.selectedWallet, wallet);
      expect(cubit.state.isWalletManuallySelected, isTrue);
      expect(cubit.state.step, SendStep.amount);
    });

    test('restores the parsed recipient when signing restarts', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      final wallet = _bitcoinLocalWallet();
      const address = 'bc1qrecipient';
      const request = PaymentRequest.bitcoin(
        address: address,
        isTestnet: false,
      );
      when(
        () => detectBitcoinStringUsecase.execute(data: address),
      ).thenAnswer((_) async => request);
      when(
        () => savePendingBitcoinTransactionUsecase.execute(
          any(),
          expectedRevision: any(named: 'expectedRevision'),
        ),
      ).thenAnswer((invocation) async {
        final transaction =
            invocation.positionalArguments.single as PendingBitcoinTransaction;
        return Ok(transaction);
      });
      cubit.setStateForTest(
        SendState(
          step: SendStep.signing,
          selectedWallet: wallet,
          copiedRawPaymentRequest: address,
          amount: '50000',
          inputAmountCurrencyCode: BitcoinUnit.sats.code,
          unsignedPsbt: 'cHNidP8=',
          signedBitcoinPsbt: 'cHNidP8=',
          pendingTransactionId: 'pending-id',
          pendingTransactionCreatedAt: DateTime.utc(2026, 8, 14),
          isSigningSession: true,
        ),
      );

      expect(await cubit.restartSigningAsDraft(), isTrue);

      expect(cubit.state.paymentRequest, request);
      expect(cubit.state.sendType, SendType.bitcoin);
      expect(cubit.state.step, SendStep.amount);
      expect(cubit.state.isSigningSession, isFalse);
      expect(cubit.state.signedBitcoinPsbt, isNull);
    });

    test(
      'waits for explicit save and preserves edits made during that save',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        final firstSave =
            Completer<Result<PendingBitcoinTransaction, SendFailure>>();
        final saved = <PendingBitcoinTransaction>[];
        when(
          () => savePendingBitcoinTransactionUsecase.execute(
            any(),
            expectedRevision: any(named: 'expectedRevision'),
          ),
        ).thenAnswer((invocation) {
          final transaction =
              invocation.positionalArguments.single
                  as PendingBitcoinTransaction;
          saved.add(transaction);
          if (saved.length == 1) return firstSave.future;
          return Future.value(Ok(transaction));
        });
        cubit.setStateForTest(
          SendState(
            sendType: SendType.bitcoin,
            selectedWallet: _bitcoinLocalWallet(),
            copiedRawPaymentRequest: 'bc1qrecipient',
            amount: '50000',
            inputAmountCurrencyCode: BitcoinUnit.sats.code,
          ),
        );

        cubit.noteChanged('Initial label');
        await Future<void>.delayed(const Duration(milliseconds: 550));
        verifyNever(
          () => savePendingBitcoinTransactionUsecase.execute(
            any(),
            expectedRevision: any(named: 'expectedRevision'),
          ),
        );

        final explicitSave = cubit.saveDraft();
        await pumpEventQueue();
        cubit.noteChanged('Updated label');
        firstSave.complete(Ok(saved.first));
        expect(await explicitSave, isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 550));

        expect(saved.map((transaction) => transaction.label), [
          'Initial label',
          'Updated label',
        ]);
        expect(cubit.state.isDraftSaved, isTrue);
        expect(cubit.state.hasUnsavedDraftChanges, isFalse);
      },
    );

    test('persists signing progress and derives its stored stage', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      final saved = <PendingBitcoinTransaction>[];
      final expectedRevisions = <int?>[];
      when(
        () => savePendingBitcoinTransactionUsecase.execute(
          any(),
          expectedRevision: any(named: 'expectedRevision'),
        ),
      ).thenAnswer((invocation) async {
        final transaction =
            invocation.positionalArguments.single as PendingBitcoinTransaction;
        saved.add(transaction);
        expectedRevisions.add(
          invocation.namedArguments[#expectedRevision] as int?,
        );
        return Ok(transaction);
      });
      final createdAt = DateTime.utc(2026, 8, 14);
      cubit.setStateForTest(
        SendState(
          step: SendStep.signing,
          sendType: SendType.bitcoin,
          selectedWallet: _bitcoinLocalWallet(),
          copiedRawPaymentRequest: 'bc1qrecipient',
          amount: '50000',
          confirmedAmountSat: 50000,
          inputAmountCurrencyCode: BitcoinUnit.sats.code,
          unsignedPsbt: 'cHNidP8=',
          pendingTransactionId: 'pending-id',
          pendingTransactionCreatedAt: createdAt,
          isSigningSession: true,
        ),
      );

      expect(await cubit.persistSigningSession(), isTrue);
      cubit.setStateForTest(
        cubit.state.copyWith(signedBitcoinPsbt: 'cHNidP8='),
      );
      expect(await cubit.persistSigningSession(), isTrue);

      expect(saved.map((transaction) => transaction.stage), [
        PendingBitcoinTransactionStage.needsSignatures,
        PendingBitcoinTransactionStage.readyToBroadcast,
      ]);
      expect(expectedRevisions, [null, saved.first.revision]);
      expect(
        saved.every((transaction) => transaction.psbt == 'cHNidP8='),
        isTrue,
      );
      expect(
        saved.every((transaction) => transaction.createdAt == createdAt),
        isTrue,
      );
    });

    test('reloads the saved draft after a revision conflict', () async {
      final wallet = _bitcoinLocalWallet();
      final updatedAt = DateTime.utc(2026, 8, 14, 1);
      final authoritative = PendingBitcoinTransaction(
        id: 'pending-id',
        walletId: wallet.id,
        stage: PendingBitcoinTransactionStage.draft,
        label: 'Saved elsewhere',
        recipient: 'bc1qauthoritative',
        amount: '',
        amountCurrencyCode: '',
        sendMax: false,
        feeSelection: FeeSelection.fastest,
        replaceByFee: true,
        createdAt: DateTime.utc(2026, 8, 14),
        updatedAt: updatedAt,
      );
      when(
        () => savePendingBitcoinTransactionUsecase.execute(
          any(),
          expectedRevision: any(named: 'expectedRevision'),
        ),
      ).thenAnswer(
        (_) async => const Err(SendPendingTransactionChangedFailure()),
      );
      when(
        () => getPendingBitcoinTransactionUsecase.execute(authoritative.id),
      ).thenAnswer((_) async => Ok(authoritative));
      when(
        () => detectBitcoinStringUsecase.execute(data: authoritative.recipient),
      ).thenThrow('Incomplete payment request');
      when(
        () => getWalletUtxosUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) async => []);
      when(
        () => watchFinishedWalletSyncsUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) => const Stream.empty());
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        SendState(
          wallets: [wallet],
          selectedWallet: wallet,
          pendingTransactionId: authoritative.id,
          pendingTransactionCreatedAt: authoritative.createdAt,
          isDraftSaved: true,
          hasUnsavedDraftChanges: true,
          copiedRawPaymentRequest: 'bc1qlocal',
          label: 'Local edit',
        ),
      );

      expect(await cubit.saveDraft(), isFalse);

      expect(cubit.state.label, authoritative.label);
      expect(cubit.state.hasUnsavedDraftChanges, isFalse);
      expect(cubit.state.persistingPendingTransaction, isFalse);
      expect(cubit.state.failure, isA<SendPendingTransactionChangedFailure>());
    });

    test('can resave a loaded draft deleted during a conflict', () async {
      final wallet = _bitcoinLocalWallet();
      final stored = PendingBitcoinTransaction(
        id: 'pending-id',
        walletId: wallet.id,
        stage: PendingBitcoinTransactionStage.draft,
        recipient: 'bc1qincomplete',
        amount: '',
        amountCurrencyCode: '',
        sendMax: false,
        feeSelection: FeeSelection.fastest,
        replaceByFee: true,
        createdAt: DateTime.utc(2026, 8, 14),
        updatedAt: DateTime.utc(2026, 8, 14),
        revision: 3,
      );
      var saveCount = 0;
      final expectedRevisions = <int?>[];
      when(
        () => savePendingBitcoinTransactionUsecase.execute(
          any(),
          expectedRevision: any(named: 'expectedRevision'),
        ),
      ).thenAnswer((invocation) async {
        expectedRevisions.add(
          invocation.namedArguments[#expectedRevision] as int?,
        );
        if (saveCount++ == 0) {
          return const Err(SendPendingTransactionChangedFailure());
        }
        return Ok(
          invocation.positionalArguments.single as PendingBitcoinTransaction,
        );
      });
      var lookupCount = 0;
      when(
        () => getPendingBitcoinTransactionUsecase.execute('pending-id'),
      ).thenAnswer((_) async {
        if (lookupCount++ == 0) {
          return Ok<PendingBitcoinTransaction?, SendFailure>(stored);
        }
        return const Ok<PendingBitcoinTransaction?, SendFailure>(null);
      });
      when(
        () => detectBitcoinStringUsecase.execute(data: stored.recipient),
      ).thenThrow('Incomplete payment request');
      when(
        () => getWalletUtxosUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) async => []);
      when(
        () => watchFinishedWalletSyncsUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) => const Stream.empty());
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(SendState(wallets: [wallet]));

      expect(await cubit.loadPendingTransaction(stored.id), isTrue);
      cubit.setStateForTest(
        cubit.state.copyWith(
          copiedRawPaymentRequest: 'bc1qlocal',
          hasUnsavedDraftChanges: true,
        ),
      );

      expect(await cubit.saveDraft(), isFalse);

      expect(cubit.state.pendingTransactionId, isNull);
      expect(cubit.state.isDraftSaved, isFalse);
      expect(cubit.state.hasUnsavedDraftChanges, isTrue);
      expect(cubit.state.persistingPendingTransaction, isFalse);
      expect(cubit.state.failure, isA<SendPendingTransactionChangedFailure>());

      expect(await cubit.saveDraft(), isTrue);
      expect(expectedRevisions, [stored.revision, null]);
    });

    test('keeps draft identity when conflict restoration fails', () async {
      final wallet = _bitcoinLocalWallet();
      final stored = PendingBitcoinTransaction(
        id: 'pending-id',
        walletId: wallet.id,
        stage: PendingBitcoinTransactionStage.draft,
        recipient: 'bc1qrecipient',
        amount: '',
        amountCurrencyCode: '',
        sendMax: false,
        feeSelection: FeeSelection.fastest,
        replaceByFee: true,
        createdAt: DateTime.utc(2026, 8, 14),
        updatedAt: DateTime.utc(2026, 8, 14),
      );
      final restore = _MockRestorePendingBitcoinTransactionUsecase();
      when(
        () => savePendingBitcoinTransactionUsecase.execute(
          any(),
          expectedRevision: any(named: 'expectedRevision'),
        ),
      ).thenAnswer(
        (_) async => const Err(SendPendingTransactionChangedFailure()),
      );
      when(
        () => getPendingBitcoinTransactionUsecase.execute(stored.id),
      ).thenAnswer(
        (_) async => Ok<PendingBitcoinTransaction?, SendFailure>(stored),
      );
      when(
        () => restore.execute(stored.id),
      ).thenAnswer((_) async => const Err(SendUnexpectedFailure()));
      final cubit = buildCubit(restorePendingTransactionUsecase: restore);
      addTearDown(cubit.close);
      cubit.setStateForTest(
        SendState(
          selectedWallet: wallet,
          pendingTransactionId: stored.id,
          isDraftSaved: true,
          hasUnsavedDraftChanges: true,
          copiedRawPaymentRequest: stored.recipient,
        ),
      );

      expect(await cubit.saveDraft(), isFalse);

      expect(cubit.state.pendingTransactionId, stored.id);
      expect(cubit.state.isDraftSaved, isTrue);
      expect(cubit.state.persistingPendingTransaction, isFalse);
      expect(cubit.state.failure, isA<SendUnexpectedFailure>());
    });

    test('can recreate a signing session deleted during a conflict', () async {
      final wallet = _bitcoinLocalWallet();
      var saveCount = 0;
      when(
        () => savePendingBitcoinTransactionUsecase.execute(
          any(),
          expectedRevision: any(named: 'expectedRevision'),
        ),
      ).thenAnswer((invocation) async {
        if (saveCount++ == 0) {
          return const Err(SendPendingTransactionChangedFailure());
        }
        return Ok(
          invocation.positionalArguments.single as PendingBitcoinTransaction,
        );
      });
      when(
        () => getPendingBitcoinTransactionUsecase.execute('pending-id'),
      ).thenAnswer(
        (_) async => const Ok<PendingBitcoinTransaction?, SendFailure>(null),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        SendState(
          step: SendStep.signing,
          sendType: SendType.bitcoin,
          selectedWallet: wallet,
          copiedRawPaymentRequest: 'bc1qrecipient',
          amount: '50000',
          confirmedAmountSat: 50000,
          inputAmountCurrencyCode: BitcoinUnit.sats.code,
          unsignedPsbt: 'cHNidP8=',
          pendingTransactionId: 'pending-id',
          isSigningSession: true,
        ),
      );

      expect(await cubit.persistSigningSession(), isFalse);
      expect(cubit.state.pendingTransactionId, isNull);
      expect(cubit.state.isSigningSession, isTrue);

      expect(await cubit.persistSigningSession(), isTrue);
      expect(cubit.state.pendingTransactionId, isNotNull);
      expect(cubit.state.persistingPendingTransaction, isFalse);
    });

    test('keeps hashlock signing sessions out of ordinary storage', () async {
      final wallet = _bitcoinLocalWallet();
      final policy = _mandatoryHashlockPolicy();
      final plan = BitcoinSigningPlan.fromPolicy(
        policy: policy,
        signers: wallet.signers,
        inputKeychains: const {BitcoinPolicyKeychain.external},
      );
      final hashlock = policy
          .requiredHashlocks(const BitcoinPolicySelection.empty())
          .single;
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        SendState(
          step: SendStep.confirm,
          sendType: SendType.bitcoin,
          selectedWallet: wallet,
          paymentRequest: const PaymentRequest.bitcoin(
            address: 'bc1qrecipient',
            isTestnet: false,
          ),
          amount: '50000',
          confirmedAmountSat: 50000,
          inputAmountCurrencyCode: BitcoinUnit.sats.code,
          unsignedPsbt: 'cHNidP8=',
          bitcoinSigningPlan: plan,
          bitcoinPolicySelection: const BitcoinPolicySelection.empty(),
          satisfiedBitcoinPolicyPreimages: {
            '${hashlock.type.name}:${hashlock.hash}',
          },
        ),
      );

      expect(await cubit.continueToBitcoinSigning(), isTrue);

      expect(cubit.state.step, SendStep.signing);
      expect(cubit.state.isSigningSession, isFalse);
      verifyNever(
        () => savePendingBitcoinTransactionUsecase.execute(
          any(),
          expectedRevision: any(named: 'expectedRevision'),
        ),
      );

      expect(await cubit.restartSigningAsDraft(), isTrue);
      expect(cubit.state.step, SendStep.amount);
      expect(cubit.state.isDraftSaved, isFalse);
      expect(cubit.state.satisfiedBitcoinPolicyPreimages, isEmpty);
      verifyNever(
        () => savePendingBitcoinTransactionUsecase.execute(
          any(),
          expectedRevision: any(named: 'expectedRevision'),
        ),
      );
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

    test('refuses a signed transaction that fails verification', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(hardwareSignReadyState());
      when(
        () => processBitcoinSignerResultUsecase.execute(
          result: 'deadbeef',
          kind: BitcoinSignerResultKind.transaction,
          currentPsbt: 'cHNidP8=',
          wallet: any(named: 'wallet'),
          selection: any(named: 'selection'),
          satisfiedPreimageKeys: any(named: 'satisfiedPreimageKeys'),
        ),
      ).thenAnswer(
        (_) async => const Err(
          BitcoinSigningFailure(BitcoinSigningFailureKind.walletMismatch),
        ),
      );

      await cubit.applyFinalBitcoinTransaction('deadbeef');

      expect(
        cubit.state.signedBitcoinTx,
        isNull,
        reason: 'a tampered transaction must never reach the broadcast path',
      );
      expect(cubit.state.failure, isA<SendTransactionSigningFailure>());
    });

    test('a signed transaction passing the output check is stored', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(hardwareSignReadyState());

      when(
        () => processBitcoinSignerResultUsecase.execute(
          result: 'deadbeef',
          kind: BitcoinSignerResultKind.transaction,
          currentPsbt: 'cHNidP8=',
          wallet: any(named: 'wallet'),
          selection: any(named: 'selection'),
          satisfiedPreimageKeys: any(named: 'satisfiedPreimageKeys'),
        ),
      ).thenAnswer(
        (_) async => const Ok(
          ProcessedBitcoinTransaction(transaction: 'deadbeef', txSize: 0),
        ),
      );

      await cubit.applyFinalBitcoinTransaction('deadbeef');

      expect(cubit.state.signedBitcoinTx, 'deadbeef');
      expect(cubit.state.failure, isNull);
      verify(
        () => processBitcoinSignerResultUsecase.execute(
          result: 'deadbeef',
          kind: BitcoinSignerResultKind.transaction,
          currentPsbt: 'cHNidP8=',
          wallet: any(named: 'wallet'),
          selection: any(named: 'selection'),
          satisfiedPreimageKeys: any(named: 'satisfiedPreimageKeys'),
        ),
      ).called(1);
    });

    test('a valid retry clears the previous verification error', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(hardwareSignReadyState());
      var attempts = 0;
      when(
        () => processBitcoinSignerResultUsecase.execute(
          result: any(named: 'result'),
          kind: BitcoinSignerResultKind.transaction,
          currentPsbt: 'cHNidP8=',
          wallet: any(named: 'wallet'),
          selection: any(named: 'selection'),
          satisfiedPreimageKeys: any(named: 'satisfiedPreimageKeys'),
        ),
      ).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) {
          return const Err(
            BitcoinSigningFailure(BitcoinSigningFailureKind.walletMismatch),
          );
        }
        return const Ok(
          ProcessedBitcoinTransaction(transaction: 'valid', txSize: 0),
        );
      });

      expect(await cubit.applyFinalBitcoinTransaction('tampered'), isFalse);
      expect(cubit.state.failure, isA<SendTransactionSigningFailure>());

      expect(await cubit.applyFinalBitcoinTransaction('valid'), isTrue);
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

        await cubit.applyFinalBitcoinTransaction('deadbeef');

        expect(cubit.state.signedBitcoinTx, isNull);
        expect(cubit.state.failure, isA<SendTransactionConfirmationFailure>());
        verifyNever(
          () => processBitcoinSignerResultUsecase.execute(
            result: any(named: 'result'),
            kind: BitcoinSignerResultKind.transaction,
            currentPsbt: any(named: 'currentPsbt'),
            wallet: any(named: 'wallet'),
            selection: any(named: 'selection'),
            satisfiedPreimageKeys: any(named: 'satisfiedPreimageKeys'),
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

    test(
      'returns to confirmation and retries an ambiguous broadcast',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        var attempts = 0;
        when(
          () => broadcastBitcoinTxUsecase.execute(
            any(),
            isPsbt: any(named: 'isPsbt'),
          ),
        ).thenAnswer((_) async {
          attempts++;
          throw BroadcastTransactionException('connection closed');
        });
        cubit.setStateForTest(
          plainSignedState().copyWith(step: SendStep.confirm),
        );

        await cubit.onConfirmTransactionClicked();
        expect(cubit.state.step, SendStep.confirm);
        expect(
          cubit.state.failure,
          isA<SendTransactionConfirmationFailure>().having(
            (failure) => failure.isBroadcastFailure,
            'isBroadcastFailure',
            isTrue,
          ),
        );

        await cubit.onConfirmTransactionClicked();

        expect(attempts, 2);
        expect(cubit.state.step, SendStep.confirm);
      },
    );
  });

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
    test('keeps a restricted wallet and recipient immutable', () async {
      final wallet = _bitcoinLocalWallet();
      final cubit = buildCubit(wallet: wallet);
      addTearDown(cubit.close);
      when(
        () => detectBitcoinStringUsecase.execute(data: 'bc1qmigration'),
      ).thenThrow(StateError('stop after the input boundary'));

      await cubit.configureRestrictedSend(recipient: 'bc1qmigration');
      await cubit.onChangedText('bc1qredirect');
      await cubit.onScannedPaymentRequest(
        'bc1qscannerredirect',
        const PaymentRequest.bitcoin(
          address: 'bc1qscannerredirect',
          isTestnet: false,
        ),
      );
      await cubit.updateSelectedWallet(_descriptorWallet());

      expect(cubit.isRestrictedSend, isTrue);
      expect(cubit.state.copiedRawPaymentRequest, 'bc1qmigration');
      expect(cubit.state.selectedWallet, wallet);
    });

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
      ).thenThrow(StateError('invalid'));

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
      ).thenThrow(StateError('invalid'));

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
      ).thenThrow(StateError('invalid'));

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
        parsing.completeError(StateError('invalid'));
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
      'keeps a newer valid submit result when an older one completes',
      () async {
        final cubit = buildCubit();
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
      final cubit = buildCubit();
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
      oldResult.completeError(StateError('old input is invalid'));
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
      final cubit = buildCubit();
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
        final wallet = _bitcoinWallet(balanceSat: 20000);
        stubSingleSignaturePolicy(wallet);
        final selected = _utxo(amountSat: 10000);
        when(
          () => prepareBitcoinSendUsecase.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
            networkFee: any(named: 'networkFee'),
            amountSat: any(named: 'amountSat'),
            drain: any(named: 'drain'),
            selectedInputs: any(named: 'selectedInputs'),
            replaceByFee: any(named: 'replaceByFee'),
            policyPath: any(named: 'policyPath'),
          ),
        ).thenThrow(NoSpendableUtxoException('selected coin disappeared'));
        when(
          () => getWalletUtxosUsecase.execute(walletId: any(named: 'walletId')),
        ).thenAnswer((_) async => [selected]);
        cubit.setStateForTest(
          SendState(
            step: SendStep.amount,
            sendType: SendType.bitcoin,
            selectedWallet: wallet,
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
        final wallet = _bitcoinWallet(balanceSat: 20000);
        stubSingleSignaturePolicy(wallet);
        when(
          () => prepareBitcoinSendUsecase.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
            networkFee: any(named: 'networkFee'),
            amountSat: any(named: 'amountSat'),
            drain: any(named: 'drain'),
            selectedInputs: any(named: 'selectedInputs'),
            replaceByFee: any(named: 'replaceByFee'),
            policyPath: any(named: 'policyPath'),
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
            selectedWallet: wallet,
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
            address: any(named: 'address'),
            networkFee: any(named: 'networkFee'),
            amountSat: captureAny(named: 'amountSat'),
            drain: any(named: 'drain'),
            selectedInputs: captureAny(named: 'selectedInputs'),
            replaceByFee: any(named: 'replaceByFee'),
            policyPath: any(named: 'policyPath'),
          ),
        ).captured;
        expect(captured[0], 5000);
        expect(captured[1] as List<WalletUtxo>, [selected]);
      },
    );

    // #2337: frozen coins cause a shortfall too, and only the generic failure
    // reaches the "manage coins" hint that tells the user what to do.
    test('with frozen coins the message stays generic', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      final wallet = _bitcoinWallet(balanceSat: 20000);
      final plan = BitcoinSigningPlan.fromPolicy(
        policy: _mandatoryRelativeTimelockPolicy(),
        signers: wallet.signers,
      );
      when(
        () => getBitcoinSigningPlanUsecase.execute(
          wallet: wallet,
          selection: const BitcoinPolicySelection.empty(),
        ),
      ).thenAnswer(
        (_) async => Ok((
          plan: plan,
          maturity: const BitcoinPolicyMaturity.empty(),
          review: null,
        )),
      );
      when(
        () => prepareBitcoinSendUsecase.execute(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
          networkFee: any(named: 'networkFee'),
          amountSat: any(named: 'amountSat'),
          drain: any(named: 'drain'),
          selectedInputs: any(named: 'selectedInputs'),
          replaceByFee: any(named: 'replaceByFee'),
          policyPath: any(named: 'policyPath'),
        ),
      ).thenThrow(InsufficientFundsException('needed 10000, available 5000'));
      when(
        () => getWalletUtxosUsecase.execute(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => [_utxo(amountSat: 15000, isFrozen: true)]);
      cubit.setStateForTest(
        SendState(
          step: SendStep.amount,
          sendType: SendType.bitcoin,
          selectedWallet: wallet,
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

  test('uses mandatory relative-timelock maturity in fee previews', () async {
    final wallet = _bitcoinLocalWallet();
    final maturity = BitcoinPolicyMaturity(
      tipHeight: 100,
      medianTimePast: null,
      utxos: [
        BitcoinPolicyUtxoMaturity(
          outpoint: 'mature:0',
          keychain: BitcoinPolicyKeychain.external,
          amountSat: BigInt.from(50000),
          confirmations: 10,
        ),
      ],
    );
    final plan = BitcoinSigningPlan.fromPolicy(
      policy: _mandatoryRelativeTimelockPolicy(),
      signers: wallet.signers,
    );
    final fee = NetworkFee.relativeFromSatPerVbyte(2);
    when(
      () => previewBitcoinFeeUsecase.execute(
        walletId: wallet.id,
        address: 'bc1qrecipient',
        amountSat: 10000,
        networkFee: fee,
        replaceByFee: true,
        selectedInputs: const [],
        drain: false,
        policyPath: any(named: 'policyPath'),
      ),
    ).thenAnswer((_) async => const BitcoinFeePreviewSlot());
    final cubit = buildCubit();
    addTearDown(cubit.close);
    cubit.setStateForTest(
      SendState(
        sendType: SendType.bitcoin,
        selectedWallet: wallet,
        paymentRequest: const PaymentRequest.bitcoin(
          address: 'bc1qrecipient',
          isTestnet: false,
        ),
        confirmedAmountSat: 10000,
        bitcoinSigningPlan: plan,
        bitcoinPolicyMaturity: maturity,
      ),
    );

    await cubit.previewBitcoinCustomFee(fee);

    final capturedPath =
        verify(
              () => previewBitcoinFeeUsecase.execute(
                walletId: wallet.id,
                address: 'bc1qrecipient',
                amountSat: 10000,
                networkFee: fee,
                replaceByFee: true,
                selectedInputs: const [],
                drain: false,
                policyPath: captureAny(named: 'policyPath'),
              ),
            ).captured.single
            as BitcoinPolicyPath;
    expect(capturedPath.requiresRelativeTimelock, isTrue);
    expect(capturedPath.eligibleExternalOutpoints, {'mature:0'});
  });

  test(
    'forwards maturity constraints for a mandatory relative timelock',
    () async {
      final wallet = _bitcoinLocalWallet();
      final policy = _mandatoryRelativeTimelockPolicy();
      final maturity = BitcoinPolicyMaturity(
        tipHeight: 100,
        medianTimePast: null,
        utxos: [
          BitcoinPolicyUtxoMaturity(
            outpoint: 'mature:0',
            keychain: BitcoinPolicyKeychain.external,
            amountSat: BigInt.from(50000),
            confirmations: 10,
          ),
          BitcoinPolicyUtxoMaturity(
            outpoint: 'immature:0',
            keychain: BitcoinPolicyKeychain.external,
            amountSat: BigInt.from(50000),
            confirmations: 9,
          ),
        ],
      );
      final plan = BitcoinSigningPlan.fromPolicy(
        policy: policy,
        signers: wallet.signers,
      );
      final fees = FeeOptions(
        fastest: NetworkFee.relativeFromSatPerVbyte(2),
        economic: NetworkFee.relativeFromSatPerVbyte(1),
        slow: NetworkFee.relativeFromSatPerVbyte(0.5),
        minRelay: NetworkFee.relativeFromSatPerVbyte(0.1),
      );
      when(
        () => getWalletUtxosUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) async => []);
      when(
        () => getBitcoinSigningPlanUsecase.execute(
          wallet: wallet,
          selection: const BitcoinPolicySelection.empty(),
        ),
      ).thenAnswer(
        (_) async => Ok((plan: plan, maturity: maturity, review: null)),
      );
      when(
        () => prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          address: 'bc1qrecipient',
          networkFee: fees.fastest,
          amountSat: 10000,
          replaceByFee: true,
          selectedInputs: const [],
          drain: false,
          policyPath: any(named: 'policyPath'),
        ),
      ).thenAnswer(
        (_) async => (unsignedPsbt: 'prepared', txSize: 100, isToSelf: false),
      );
      when(
        () => applyBitcoinPolicyPreimagesUsecase.execute(
          psbt: 'prepared',
          preimages: any(named: 'preimages'),
        ),
      ).thenAnswer((_) async => const Ok('prepared'));
      when(
        () => getBitcoinSigningPlanUsecase.execute(
          wallet: wallet,
          psbt: 'prepared',
          selection: const BitcoinPolicySelection.empty(),
        ),
      ).thenAnswer(
        (_) async => Ok((
          plan: plan,
          maturity: const BitcoinPolicyMaturity.empty(),
          review: null,
        )),
      );
      when(
        () => calculateBitcoinAbsoluteFeesUsecase.execute(psbt: 'prepared'),
      ).thenAnswer((_) async => 1000);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        SendState(
          sendType: SendType.bitcoin,
          selectedWallet: wallet,
          paymentRequest: const PaymentRequest.bitcoin(
            address: 'bc1qrecipient',
            isTestnet: false,
          ),
          confirmedAmountSat: 10000,
          bitcoinFeesList: fees,
          liquidFeesList: fees,
        ),
      );

      await cubit.createTransaction();

      final capturedPath =
          verify(
                () => prepareBitcoinSendUsecase.execute(
                  walletId: wallet.id,
                  address: 'bc1qrecipient',
                  networkFee: fees.fastest,
                  amountSat: 10000,
                  replaceByFee: true,
                  selectedInputs: const [],
                  drain: false,
                  policyPath: captureAny(named: 'policyPath'),
                ),
              ).captured.single
              as BitcoinPolicyPath;
      expect(capturedPath.external, isEmpty);
      expect(capturedPath.requiresRelativeTimelock, isTrue);
      expect(capturedPath.eligibleExternalOutpoints, {'mature:0'});
      expect(capturedPath.eligibleInternalOutpoints, isEmpty);
    },
  );

  group('SendCubit spending path changes', () {
    late Wallet wallet;
    late BitcoinWalletPolicy policy;
    late BitcoinPolicySelection previousSelection;
    late BitcoinPolicySelection requestedSelection;
    late BitcoinSigningPlan previousPlan;
    late BitcoinSigningPlan candidatePlan;
    late BitcoinSigningPlan mergedPlan;
    late FeeOptions fees;

    setUp(() {
      final signers = [
        _bitcoinLocalWallet().signers.single,
        WalletSigner.single(
          id: 'signer-1',
          descriptorKeyId: 'key-1',
          masterFingerprint: '22222222',
          xpubFingerprint: '22222222',
          xpub: 'remote-2',
          signer: SignerEntity.remote,
          signerDevice: null,
        ),
        WalletSigner.single(
          id: 'signer-2',
          descriptorKeyId: 'key-2',
          masterFingerprint: '33333333',
          xpubFingerprint: '33333333',
          xpub: 'remote-3',
          signer: SignerEntity.remote,
          signerDevice: null,
        ),
      ];
      wallet = _bitcoinLocalWallet().copyWith(signers: signers);
      policy = _selectableThresholdPolicy(signers);
      final selector = policy
          .pathSelectors(const BitcoinPolicySelection.empty())
          .single;
      previousSelection = policy.select(
        current: const BitcoinPolicySelection.empty(),
        requirement: selector,
        selectedIndices: const {0, 1},
      );
      requestedSelection = policy.select(
        current: const BitcoinPolicySelection.empty(),
        requirement: selector,
        selectedIndices: const {0, 2},
      );
      previousPlan = BitcoinSigningPlan.fromPolicy(
        policy: policy,
        signers: signers,
        selection: previousSelection,
        signedDescriptorKeyIdsByKeychain: const {
          BitcoinPolicyKeychain.external: {'key-0'},
        },
        inputKeychains: const {BitcoinPolicyKeychain.external},
      );
      candidatePlan = BitcoinSigningPlan.fromPolicy(
        policy: policy,
        signers: signers,
        selection: requestedSelection,
        inputKeychains: const {BitcoinPolicyKeychain.external},
      );
      mergedPlan = BitcoinSigningPlan.fromPolicy(
        policy: policy,
        signers: signers,
        selection: requestedSelection,
        signedDescriptorKeyIdsByKeychain: const {
          BitcoinPolicyKeychain.external: {'key-0'},
        },
        inputKeychains: const {BitcoinPolicyKeychain.external},
      );
      fees = FeeOptions(
        fastest: NetworkFee.relativeFromSatPerVbyte(2),
        economic: NetworkFee.relativeFromSatPerVbyte(1),
        slow: NetworkFee.relativeFromSatPerVbyte(0.5),
        minRelay: NetworkFee.relativeFromSatPerVbyte(0.1),
      );
      when(
        () => getBitcoinSigningPlanUsecase.execute(
          wallet: wallet,
          selection: requestedSelection,
        ),
      ).thenAnswer(
        (_) async => Ok((
          plan: candidatePlan,
          maturity: const BitcoinPolicyMaturity.empty(),
          review: null,
        )),
      );
      when(
        () => getBitcoinSigningPlanUsecase.execute(
          wallet: wallet,
          psbt: 'candidate',
          selection: requestedSelection,
        ),
      ).thenAnswer(
        (_) async => Ok((
          plan: candidatePlan,
          maturity: const BitcoinPolicyMaturity.empty(),
          review: null,
        )),
      );
      when(
        () => prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          address: 'bc1qrecipient',
          networkFee: fees.fastest,
          amountSat: 10000,
          replaceByFee: true,
          selectedInputs: const [],
          drain: false,
          policyPath: any(named: 'policyPath'),
        ),
      ).thenAnswer(
        (_) async => (unsignedPsbt: 'candidate', txSize: 100, isToSelf: false),
      );
      when(
        () => getWalletUtxosUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) async => []);
      when(
        () => applyBitcoinPolicyPreimagesUsecase.execute(
          psbt: 'candidate',
          preimages: any(named: 'preimages'),
        ),
      ).thenAnswer((_) async => const Ok('candidate'));
      when(
        () => calculateBitcoinAbsoluteFeesUsecase.execute(psbt: 'candidate'),
      ).thenAnswer((_) async => 1000);
    });

    SendState state() => SendState(
      sendType: SendType.bitcoin,
      selectedWallet: wallet,
      paymentRequest: const PaymentRequest.bitcoin(
        address: 'bc1qrecipient',
        isTestnet: false,
      ),
      confirmedAmountSat: 10000,
      bitcoinFeesList: fees,
      liquidFeesList: fees,
      unsignedPsbt: 'signed-current',
      bitcoinSigningPlan: previousPlan,
      bitcoinPolicySelection: previousSelection,
    );

    test(
      'preserves signatures when the unsigned transaction is unchanged',
      () async {
        when(
          () => processBitcoinSignerResultUsecase.execute(
            result: 'signed-current',
            kind: BitcoinSignerResultKind.psbt,
            currentPsbt: 'candidate',
            wallet: wallet,
            selection: requestedSelection,
            satisfiedPreimageKeys: any(named: 'satisfiedPreimageKeys'),
          ),
        ).thenAnswer(
          (_) async => Ok(
            ProcessedBitcoinPsbt(
              psbt: 'merged',
              isFinalized: false,
              txSize: 100,
              absoluteFeesSat: 1000,
              signingPlan: mergedPlan,
            ),
          ),
        );
        final cubit = buildCubit()..setStateForTest(state());
        addTearDown(cubit.close);

        final restart = await cubit.applyBitcoinPolicySelection(
          requestedSelection,
        );

        expect(restart, isNull);
        expect(cubit.state.unsignedPsbt, 'merged');
        expect(cubit.state.bitcoinSigningPlan, same(mergedPlan));
      },
    );

    test(
      'keeps the signed PSBT until a changed transaction is confirmed',
      () async {
        when(
          () => processBitcoinSignerResultUsecase.execute(
            result: 'signed-current',
            kind: BitcoinSignerResultKind.psbt,
            currentPsbt: 'candidate',
            wallet: wallet,
            selection: requestedSelection,
            satisfiedPreimageKeys: any(named: 'satisfiedPreimageKeys'),
          ),
        ).thenAnswer(
          (_) async => const Err(
            BitcoinSigningFailure(BitcoinSigningFailureKind.walletMismatch),
          ),
        );
        final cubit = buildCubit()..setStateForTest(state());
        addTearDown(cubit.close);

        final restart = await cubit.applyBitcoinPolicySelection(
          requestedSelection,
        );

        expect(restart, same(requestedSelection));
        expect(cubit.state.unsignedPsbt, 'signed-current');
        expect(cubit.state.bitcoinSigningPlan, same(previousPlan));
      },
    );
  });

  group('SendCubit navigation while preparing a transaction', () {
    test('does not leave confirmation during build or signing', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      for (final state in [
        const SendState(step: SendStep.confirm, buildingTransaction: true),
        const SendState(step: SendStep.confirm, signingTransaction: true),
      ]) {
        cubit.setStateForTest(state);
        cubit.backClicked();

        expect(cubit.state.step, SendStep.confirm);
      }
    });
  });

  group('SendCubit external signing results', () {
    test('a slower signer result cannot replace a newer one', () async {
      final older =
          Completer<
            Result<ProcessedBitcoinSignerResult, BitcoinSigningFailure>
          >();
      final newer =
          Completer<
            Result<ProcessedBitcoinSignerResult, BitcoinSigningFailure>
          >();
      when(
        () => processBitcoinSignerResultUsecase.execute(
          result: any(named: 'result'),
          kind: BitcoinSignerResultKind.detect,
          currentPsbt: 'prepared-psbt',
          wallet: any(named: 'wallet'),
          selection: any(named: 'selection'),
          satisfiedPreimageKeys: any(named: 'satisfiedPreimageKeys'),
        ),
      ).thenAnswer((invocation) {
        final result = invocation.namedArguments[#result] as String;
        return result == 'older' ? older.future : newer.future;
      });
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        SendState(
          unsignedPsbt: 'prepared-psbt',
          selectedWallet: _bitcoinLocalWallet(),
        ),
      );

      final olderRequest = cubit.applyExternalBitcoinSigningResult('older');
      final newerRequest = cubit.applyExternalBitcoinSigningResult('newer');
      newer.complete(
        const Ok(
          ProcessedBitcoinTransaction(transaction: 'newer', txSize: 100),
        ),
      );
      expect(await newerRequest, isTrue);
      older.complete(
        const Ok(
          ProcessedBitcoinTransaction(transaction: 'older', txSize: 100),
        ),
      );

      expect(await olderRequest, isFalse);
      expect(cubit.state.signedBitcoinTx, 'newer');
    });

    test('a transaction edit discards an in-flight signer result', () async {
      final signerResult =
          Completer<
            Result<ProcessedBitcoinSignerResult, BitcoinSigningFailure>
          >();
      when(
        () => processBitcoinSignerResultUsecase.execute(
          result: 'signed-transaction',
          kind: BitcoinSignerResultKind.detect,
          currentPsbt: 'prepared-psbt',
          wallet: any(named: 'wallet'),
          selection: any(named: 'selection'),
          satisfiedPreimageKeys: any(named: 'satisfiedPreimageKeys'),
        ),
      ).thenAnswer((_) => signerResult.future);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        SendState(
          unsignedPsbt: 'prepared-psbt',
          selectedWallet: _bitcoinLocalWallet(),
        ),
      );

      final signing = cubit.applyExternalBitcoinSigningResult(
        'signed-transaction',
      );
      await cubit.amountChanged(amount: '1', isMax: true);
      signerResult.complete(
        const Ok(
          ProcessedBitcoinTransaction(transaction: 'stale', txSize: 100),
        ),
      );

      expect(await signing, isFalse);
      expect(cubit.state.signedBitcoinTx, isNull);
    });

    test('accepts a verified final raw transaction', () async {
      when(
        () => processBitcoinSignerResultUsecase.execute(
          result: 'signed-transaction',
          kind: BitcoinSignerResultKind.transaction,
          currentPsbt: 'prepared-psbt',
          wallet: any(named: 'wallet'),
          selection: any(named: 'selection'),
          satisfiedPreimageKeys: any(named: 'satisfiedPreimageKeys'),
        ),
      ).thenAnswer(
        (_) async => const Ok(
          ProcessedBitcoinTransaction(
            transaction: 'verified-transaction',
            txSize: 141,
          ),
        ),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        SendState(
          unsignedPsbt: 'prepared-psbt',
          selectedWallet: _bitcoinLocalWallet(),
        ),
      );

      await cubit.applyFinalBitcoinTransaction('signed-transaction');

      expect(cubit.state.signedBitcoinTx, 'verified-transaction');
      expect(cubit.state.signedBitcoinPsbt, isNull);
      expect(cubit.state.bitcoinTxSize, 141);
      expect(cubit.state.failure, isNull);
    });

    test('rejects a final raw transaction that fails verification', () async {
      when(
        () => processBitcoinSignerResultUsecase.execute(
          result: 'different-transaction',
          kind: BitcoinSignerResultKind.transaction,
          currentPsbt: 'prepared-psbt',
          wallet: any(named: 'wallet'),
          selection: any(named: 'selection'),
          satisfiedPreimageKeys: any(named: 'satisfiedPreimageKeys'),
        ),
      ).thenAnswer(
        (_) async => const Err(
          BitcoinSigningFailure(BitcoinSigningFailureKind.walletMismatch),
        ),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        SendState(
          unsignedPsbt: 'prepared-psbt',
          selectedWallet: _bitcoinLocalWallet(),
        ),
      );

      await cubit.applyFinalBitcoinTransaction('different-transaction');

      expect(cubit.state.signedBitcoinTx, isNull);
      expect(cubit.state.failure, isA<SendTransactionSigningFailure>());
      expect(cubit.state.signingTransaction, isFalse);
    });

    test('rolls back a signature that could not be persisted', () async {
      when(
        () => processBitcoinSignerResultUsecase.execute(
          result: 'signed-transaction',
          kind: BitcoinSignerResultKind.transaction,
          currentPsbt: 'prepared-psbt',
          wallet: any(named: 'wallet'),
          selection: any(named: 'selection'),
          satisfiedPreimageKeys: any(named: 'satisfiedPreimageKeys'),
        ),
      ).thenAnswer(
        (_) async => const Ok(
          ProcessedBitcoinTransaction(
            transaction: 'verified-transaction',
            txSize: 141,
          ),
        ),
      );
      when(
        () => savePendingBitcoinTransactionUsecase.execute(
          any(),
          expectedRevision: any(named: 'expectedRevision'),
        ),
      ).thenAnswer((_) async => const Err(SendPersistenceFailure()));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(
        SendState(
          step: SendStep.signing,
          sendType: SendType.bitcoin,
          selectedWallet: _bitcoinLocalWallet(),
          copiedRawPaymentRequest: 'bc1qrecipient',
          amount: '50000',
          confirmedAmountSat: 50000,
          inputAmountCurrencyCode: BitcoinUnit.sats.code,
          unsignedPsbt: 'prepared-psbt',
          pendingTransactionId: 'pending-id',
          pendingTransactionCreatedAt: DateTime.utc(2026, 8, 14),
          isSigningSession: true,
        ),
      );

      final accepted = await cubit.applyFinalBitcoinTransaction(
        'signed-transaction',
      );

      expect(accepted, isFalse);
      expect(cubit.state.unsignedPsbt, 'prepared-psbt');
      expect(cubit.state.signedBitcoinTx, isNull);
      expect(cubit.state.failure, isA<SendPersistenceFailure>());
    });
  });
}
