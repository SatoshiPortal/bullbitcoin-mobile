import 'dart:typed_data';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/send/domain/pending_bitcoin_transaction.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_bitcoin_signing_plan_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_pending_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/restore_pending_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/validate_pending_bitcoin_transaction_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetPendingBitcoinTransactionUsecase extends Mock
    implements GetPendingBitcoinTransactionUsecase {}

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class _MockGetWalletUtxosUsecase extends Mock
    implements GetWalletUtxosUsecase {}

class _MockDetectBitcoinStringUsecase extends Mock
    implements DetectBitcoinStringUsecase {}

class _MockValidatePendingBitcoinTransactionUsecase extends Mock
    implements ValidatePendingBitcoinTransactionUsecase {}

class _MockGetBitcoinSigningPlanUsecase extends Mock
    implements GetBitcoinSigningPlanUsecase {}

class _MockCalculateBitcoinAbsoluteFeesUsecase extends Mock
    implements CalculateBitcoinAbsoluteFeesUsecase {}

class _MockConvertSatsToCurrencyAmountUsecase extends Mock
    implements ConvertSatsToCurrencyAmountUsecase {}

void main() {
  late _MockGetPendingBitcoinTransactionUsecase getPending;
  late _MockGetWalletUsecase getWallet;
  late _MockGetWalletUtxosUsecase getUtxos;
  late _MockDetectBitcoinStringUsecase detectBitcoinString;
  late _MockValidatePendingBitcoinTransactionUsecase validatePending;
  late _MockGetBitcoinSigningPlanUsecase getSigningPlan;
  late _MockCalculateBitcoinAbsoluteFeesUsecase calculateFees;
  late _MockConvertSatsToCurrencyAmountUsecase convertSats;
  late RestorePendingBitcoinTransactionUsecase usecase;

  setUp(() {
    getPending = _MockGetPendingBitcoinTransactionUsecase();
    getWallet = _MockGetWalletUsecase();
    getUtxos = _MockGetWalletUtxosUsecase();
    detectBitcoinString = _MockDetectBitcoinStringUsecase();
    validatePending = _MockValidatePendingBitcoinTransactionUsecase();
    getSigningPlan = _MockGetBitcoinSigningPlanUsecase();
    calculateFees = _MockCalculateBitcoinAbsoluteFeesUsecase();
    convertSats = _MockConvertSatsToCurrencyAmountUsecase();
    usecase = RestorePendingBitcoinTransactionUsecase(
      getPending,
      getWallet,
      getUtxos,
      detectBitcoinString,
      validatePending,
      getSigningPlan,
      calculateFees,
      convertSats,
    );

    when(() => getWallet.execute(_wallet.id)).thenAnswer((_) async => _wallet);
    when(
      () => getUtxos.execute(walletId: _wallet.id),
    ).thenAnswer((_) async => [_selectedUtxo, _otherUtxo]);
  });

  test(
    'restores a draft with incomplete input and its selected coins',
    () async {
      final draft = _pendingTransaction(
        stage: PendingBitcoinTransactionStage.draft,
        recipient: 'tb1qincomplete',
        selectedOutpoints: {'funding:0'},
      );
      when(() => getPending.execute(draft.id)).thenAnswer(
        (_) async => Ok<PendingBitcoinTransaction?, SendFailure>(draft),
      );
      when(
        () => detectBitcoinString.execute(data: draft.recipient),
      ).thenThrow('Incomplete payment request');

      final result = await usecase.execute(draft.id);

      final restored =
          (result as Ok<RestoredPendingBitcoinTransaction, SendFailure>).value;
      expect(restored.paymentRequest, isNull);
      expect(restored.selectedUtxos, [_selectedUtxo]);
      verifyNever(() => validatePending.execute(draft));
    },
  );

  test(
    'revalidates a signing session and restores its signing state',
    () async {
      final stored = _pendingTransaction(
        stage: PendingBitcoinTransactionStage.needsSignatures,
        recipient: 'tb1qrecipient',
        psbt: 'cHNidP8=',
      );
      const request = PaymentRequest.bitcoin(
        address: 'tb1qrecipient',
        isTestnet: true,
      );
      when(() => getPending.execute(stored.id)).thenAnswer(
        (_) async => Ok<PendingBitcoinTransaction?, SendFailure>(stored),
      );
      when(
        () => detectBitcoinString.execute(data: stored.recipient),
      ).thenAnswer((_) async => request);
      when(() => validatePending.execute(stored)).thenAnswer(
        (_) async => Ok<PendingBitcoinTransaction, SendFailure>(stored),
      );
      when(
        () => getSigningPlan.execute(
          wallet: _wallet,
          psbt: stored.psbt,
          selection: stored.policySelection,
          allowSpentWalletInputs: true,
        ),
      ).thenAnswer(
        (_) async => Ok((
          plan: _signingPlan,
          maturity: const BitcoinPolicyMaturity.empty(),
          review: null,
        )),
      );
      when(
        () => calculateFees.execute(psbt: stored.psbt!),
      ).thenAnswer((_) async => 321);

      final result = await usecase.execute(stored.id);

      final restored =
          (result as Ok<RestoredPendingBitcoinTransaction, SendFailure>).value;
      expect(restored.paymentRequest, request);
      expect(restored.signingPlan, _signingPlan);
      expect(restored.absoluteFeesSat, 321);
    },
  );

  test('restores a conflicted session using its spent wallet inputs', () async {
    final stored = _pendingTransaction(
      stage: PendingBitcoinTransactionStage.needsSignatures,
      recipient: 'tb1qrecipient',
      psbt: 'cHNidP8=',
    );
    final conflicted = stored.copyWith(isConflict: true);
    when(() => getPending.execute(stored.id)).thenAnswer(
      (_) async => Ok<PendingBitcoinTransaction?, SendFailure>(stored),
    );
    when(() => detectBitcoinString.execute(data: stored.recipient)).thenAnswer(
      (_) async => const PaymentRequest.bitcoin(
        address: 'tb1qrecipient',
        isTestnet: true,
      ),
    );
    when(() => validatePending.execute(stored)).thenAnswer(
      (_) async => Ok<PendingBitcoinTransaction, SendFailure>(conflicted),
    );
    when(
      () => getSigningPlan.execute(
        wallet: _wallet,
        psbt: stored.psbt,
        selection: stored.policySelection,
        allowSpentWalletInputs: true,
      ),
    ).thenAnswer(
      (_) async => Ok((
        plan: _signingPlan,
        maturity: const BitcoinPolicyMaturity.empty(),
        review: null,
      )),
    );
    when(
      () => calculateFees.execute(psbt: stored.psbt!),
    ).thenAnswer((_) async => 321);

    final result = await usecase.execute(stored.id);

    expect((result as Ok).value.transaction.isConflict, isTrue);
    verify(
      () => getSigningPlan.execute(
        wallet: _wallet,
        psbt: stored.psbt,
        selection: stored.policySelection,
        allowSpentWalletInputs: true,
      ),
    ).called(1);
  });

  test('rejects a missing stored transaction', () async {
    when(() => getPending.execute('missing')).thenAnswer(
      (_) async => const Ok<PendingBitcoinTransaction?, SendFailure>(null),
    );

    final result = await usecase.execute('missing');

    expect((result as Err).failure, isA<SendStoredTransactionInvalidFailure>());
    verifyNever(() => getWallet.execute(any()));
  });

  test('rejects a stored transaction whose wallet is unavailable', () async {
    final stored = _pendingTransaction(
      stage: PendingBitcoinTransactionStage.draft,
      recipient: '',
    );
    when(() => getPending.execute(stored.id)).thenAnswer(
      (_) async => Ok<PendingBitcoinTransaction?, SendFailure>(stored),
    );
    when(
      () => getWallet.execute(stored.walletId),
    ).thenAnswer((_) async => null);

    final result = await usecase.execute(stored.id);

    expect((result as Err).failure, isA<SendStoredTransactionInvalidFailure>());
  });

  test('forwards stored transaction validation failures', () async {
    final stored = _pendingTransaction(
      stage: PendingBitcoinTransactionStage.needsSignatures,
      recipient: 'tb1qrecipient',
      psbt: 'cHNidP8=',
    );
    when(() => getPending.execute(stored.id)).thenAnswer(
      (_) async => Ok<PendingBitcoinTransaction?, SendFailure>(stored),
    );
    when(() => detectBitcoinString.execute(data: stored.recipient)).thenAnswer(
      (_) async => const PaymentRequest.bitcoin(
        address: 'tb1qrecipient',
        isTestnet: true,
      ),
    );
    when(() => validatePending.execute(stored)).thenAnswer(
      (_) async => const Err(SendPendingTransactionChangedFailure()),
    );

    final result = await usecase.execute(stored.id);

    expect(
      (result as Err).failure,
      isA<SendPendingTransactionChangedFailure>(),
    );
  });

  test('maps signing-plan failures to an invalid stored transaction', () async {
    final stored = _pendingTransaction(
      stage: PendingBitcoinTransactionStage.needsSignatures,
      recipient: 'tb1qrecipient',
      psbt: 'cHNidP8=',
    );
    when(() => getPending.execute(stored.id)).thenAnswer(
      (_) async => Ok<PendingBitcoinTransaction?, SendFailure>(stored),
    );
    when(() => detectBitcoinString.execute(data: stored.recipient)).thenAnswer(
      (_) async => const PaymentRequest.bitcoin(
        address: 'tb1qrecipient',
        isTestnet: true,
      ),
    );
    when(() => validatePending.execute(stored)).thenAnswer(
      (_) async => Ok<PendingBitcoinTransaction, SendFailure>(stored),
    );
    when(
      () => getSigningPlan.execute(
        wallet: _wallet,
        psbt: stored.psbt,
        selection: stored.policySelection,
        allowSpentWalletInputs: true,
      ),
    ).thenAnswer(
      (_) async => const Err(
        BitcoinSigningFailure(BitcoinSigningFailureKind.walletMismatch),
      ),
    );

    final result = await usecase.execute(stored.id);

    expect((result as Err).failure, isA<SendStoredTransactionInvalidFailure>());
  });

  test('maps dependency exceptions to an unexpected failure', () async {
    final stored = _pendingTransaction(
      stage: PendingBitcoinTransactionStage.draft,
      recipient: '',
    );
    when(() => getPending.execute(stored.id)).thenAnswer(
      (_) async => Ok<PendingBitcoinTransaction?, SendFailure>(stored),
    );
    when(() => getWallet.execute(stored.walletId)).thenThrow(Exception('boom'));

    final result = await usecase.execute(stored.id);

    expect((result as Err).failure, isA<SendUnexpectedFailure>());
  });
}

final _signer = WalletSigner.single(
  masterFingerprint: '11111111',
  xpubFingerprint: '11111112',
  xpub: 'tpub',
  derivationPath: "m/84'/1'/0'",
  signer: SignerEntity.local,
  signerDevice: null,
);

final _wallet = Wallet(
  origin: 'wallet-id',
  network: Network.bitcoinTestnet,
  signers: [_signer],
  scriptType: ScriptType.bip84,
  publicDescriptor: 'wpkh(tpub/<0;1>/*)#descriptor',
  balanceSat: BigInt.from(3000),
);

final _policyKey = BitcoinPolicyKey(
  kind: BitcoinPolicyKeyKind.fingerprint,
  value: '11111111',
);

final _policy = BitcoinWalletPolicy(
  external: BitcoinSpendingPolicy(
    root: BitcoinSignaturePolicyNode(id: 'signature', key: _policyKey),
    requiresPath: false,
  ),
  internal: BitcoinSpendingPolicy(
    root: BitcoinSignaturePolicyNode(id: 'signature', key: _policyKey),
    requiresPath: false,
  ),
);

final _signingPlan = BitcoinSigningPlan.fromPolicy(
  policy: _policy,
  signers: [_signer],
  inputKeychains: {BitcoinPolicyKeychain.external},
);

final _selectedUtxo = WalletUtxo.bitcoin(
  walletId: _wallet.id,
  txId: 'funding',
  vout: 0,
  scriptPubkey: Uint8List(0),
  amountSat: BigInt.from(1000),
  address: 'tb1qselected',
);

final _otherUtxo = WalletUtxo.bitcoin(
  walletId: _wallet.id,
  txId: 'other',
  vout: 1,
  scriptPubkey: Uint8List(0),
  amountSat: BigInt.from(2000),
  address: 'tb1qother',
);

PendingBitcoinTransaction _pendingTransaction({
  required PendingBitcoinTransactionStage stage,
  required String recipient,
  String? psbt,
  Set<String> selectedOutpoints = const {},
}) => PendingBitcoinTransaction(
  id: 'pending-id',
  walletId: _wallet.id,
  stage: stage,
  recipient: recipient,
  amount: stage == PendingBitcoinTransactionStage.draft ? '' : '500',
  amountCurrencyCode: stage == PendingBitcoinTransactionStage.draft
      ? ''
      : 'sats',
  sendMax: false,
  feeSelection: FeeSelection.fastest,
  replaceByFee: true,
  selectedOutpoints: selectedOutpoints,
  psbt: psbt,
  createdAt: DateTime.utc(2026, 8, 14),
  updatedAt: DateTime.utc(2026, 8, 14),
);
