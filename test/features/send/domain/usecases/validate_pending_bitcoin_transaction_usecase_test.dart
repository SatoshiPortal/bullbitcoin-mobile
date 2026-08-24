import 'dart:typed_data';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_signing_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_psbt_review.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/send/domain/pending_bitcoin_transaction.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_bitcoin_signing_plan_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/validate_pending_bitcoin_transaction_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class _MockGetWalletUtxosUsecase extends Mock
    implements GetWalletUtxosUsecase {}

class _MockBitcoinSigningPort extends Mock implements BitcoinSigningPort {}

class _MockGetBitcoinSigningPlanUsecase extends Mock
    implements GetBitcoinSigningPlanUsecase {}

void main() {
  late _MockGetWalletUsecase getWalletUsecase;
  late _MockGetWalletUtxosUsecase getWalletUtxosUsecase;
  late _MockBitcoinSigningPort signingPort;
  late _MockGetBitcoinSigningPlanUsecase getSigningPlanUsecase;
  late ValidatePendingBitcoinTransactionUsecase usecase;

  setUp(() {
    getWalletUsecase = _MockGetWalletUsecase();
    getWalletUtxosUsecase = _MockGetWalletUtxosUsecase();
    signingPort = _MockBitcoinSigningPort();
    getSigningPlanUsecase = _MockGetBitcoinSigningPlanUsecase();
    usecase = ValidatePendingBitcoinTransactionUsecase(
      getWalletUsecase,
      getWalletUtxosUsecase,
      signingPort,
      getSigningPlanUsecase,
    );

    when(
      () => getWalletUsecase.execute('wallet-id'),
    ).thenAnswer((_) async => _wallet);
    when(
      () => getSigningPlanUsecase.execute(
        wallet: _wallet,
        psbt: 'cHNidP8=',
        selection: const BitcoinPolicySelection.empty(),
        allowSpentWalletInputs: true,
      ),
    ).thenAnswer((_) async => Ok(_details(_review())));
  });

  test(
    'revalidates input conflicts and readiness from the stored PSBT',
    () async {
      when(
        () => getWalletUtxosUsecase.execute(walletId: 'wallet-id'),
      ).thenAnswer((_) async => const []);
      when(() => signingPort.finalizePsbt('cHNidP8=')).thenAnswer(
        (_) async => const Ok((psbt: 'cHNidP8=', isFinalized: false)),
      );

      final conflicted = await usecase.execute(_pendingTransaction);

      expect(conflicted, isA<Ok<PendingBitcoinTransaction, SendFailure>>());
      final conflictedValue =
          (conflicted as Ok<PendingBitcoinTransaction, SendFailure>).value;
      expect(conflictedValue.isConflict, isTrue);
      expect(
        conflictedValue.stage,
        PendingBitcoinTransactionStage.needsSignatures,
      );
      expect(conflictedValue.signersNeeded, 1);

      when(
        () => getWalletUtxosUsecase.execute(walletId: 'wallet-id'),
      ).thenAnswer((_) async => [_utxo]);
      when(() => signingPort.finalizePsbt('cHNidP8=')).thenAnswer(
        (_) async => const Ok((psbt: 'cHNidP8=', isFinalized: true)),
      );

      final ready = await usecase.execute(_pendingTransaction);

      final readyValue =
          (ready as Ok<PendingBitcoinTransaction, SendFailure>).value;
      expect(readyValue.isConflict, isFalse);
      expect(readyValue.stage, PendingBitcoinTransactionStage.readyToBroadcast);
      expect(readyValue.signersNeeded, 0);
    },
  );

  test(
    'rejects a PSBT whose recipient differs from the stored transaction',
    () async {
      when(
        () => getSigningPlanUsecase.execute(
          wallet: _wallet,
          psbt: 'cHNidP8=',
          selection: const BitcoinPolicySelection.empty(),
          allowSpentWalletInputs: true,
        ),
      ).thenAnswer(
        (_) async => Ok(_details(_review(recipient: 'tb1qdifferent'))),
      );

      final result = await usecase.execute(_pendingTransaction);

      expect(result, isA<Err<PendingBitcoinTransaction, SendFailure>>());
      expect(
        (result as Err<PendingBitcoinTransaction, SendFailure>).failure,
        isA<SendStoredTransactionInvalidFailure>(),
      );
    },
  );

  test('accepts a recipient output owned by the same wallet', () async {
    when(
      () => getSigningPlanUsecase.execute(
        wallet: _wallet,
        psbt: 'cHNidP8=',
        selection: const BitcoinPolicySelection.empty(),
        allowSpentWalletInputs: true,
      ),
    ).thenAnswer(
      (_) async => Ok(_details(_review(recipientWalletOwned: true))),
    );
    when(
      () => getWalletUtxosUsecase.execute(walletId: 'wallet-id'),
    ).thenAnswer((_) async => [_utxo]);
    when(
      () => signingPort.finalizePsbt('cHNidP8='),
    ).thenAnswer((_) async => const Ok((psbt: 'cHNidP8=', isFinalized: false)));

    final result = await usecase.execute(_pendingTransaction);

    expect(result, isA<Ok<PendingBitcoinTransaction, SendFailure>>());
  });

  test('accepts an uppercase Bech32 recipient from the stored draft', () async {
    when(
      () => getSigningPlanUsecase.execute(
        wallet: _wallet,
        psbt: 'cHNidP8=',
        selection: const BitcoinPolicySelection.empty(),
        allowSpentWalletInputs: true,
      ),
    ).thenAnswer(
      (_) async => Ok(_details(_review(recipient: 'TB1QRECIPIENT'))),
    );
    when(
      () => getWalletUtxosUsecase.execute(walletId: 'wallet-id'),
    ).thenAnswer((_) async => [_utxo]);
    when(
      () => signingPort.finalizePsbt('cHNidP8='),
    ).thenAnswer((_) async => const Ok((psbt: 'cHNidP8=', isFinalized: false)));

    final result = await usecase.execute(_pendingTransaction);

    expect(result, isA<Ok<PendingBitcoinTransaction, SendFailure>>());
  });

  test(
    'keeps a validated finalized PSBT ready across repeated restores',
    () async {
      when(
        () => getSigningPlanUsecase.execute(
          wallet: _wallet,
          psbt: 'cHNidP8=',
          selection: const BitcoinPolicySelection.empty(),
          allowSpentWalletInputs: true,
        ),
      ).thenAnswer((_) async => Ok(_details(_review(isFinalized: true))));
      when(
        () => getWalletUtxosUsecase.execute(walletId: 'wallet-id'),
      ).thenAnswer((_) async => [_utxo]);

      final first = await usecase.execute(_pendingTransaction);
      final second = await usecase.execute(
        (first as Ok<PendingBitcoinTransaction, SendFailure>).value,
      );

      expect(
        (second as Ok<PendingBitcoinTransaction, SendFailure>).value.stage,
        PendingBitcoinTransactionStage.readyToBroadcast,
      );
      verifyNever(() => signingPort.finalizePsbt(any()));
    },
  );
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
  balanceSat: BigInt.from(51000),
);

final _policyKey = BitcoinPolicyKey(
  kind: BitcoinPolicyKeyKind.fingerprint,
  value: '11111111',
);

BitcoinSpendingPolicy _spendingPolicy() => BitcoinSpendingPolicy(
  root: BitcoinSignaturePolicyNode(id: 'signature', key: _policyKey),
  requiresPath: false,
);

final _policy = BitcoinWalletPolicy(
  external: _spendingPolicy(),
  internal: _spendingPolicy(),
);

final _signingPlan = BitcoinSigningPlan.fromPolicy(
  policy: _policy,
  signers: [_signer],
  inputKeychains: {BitcoinPolicyKeychain.external},
);

BitcoinSigningPlanDetails _details(BitcoinPsbtReview review) => (
  plan: _signingPlan,
  maturity: const BitcoinPolicyMaturity.empty(),
  review: review,
);

final _pendingTransaction = PendingBitcoinTransaction(
  id: 'pending-id',
  walletId: 'wallet-id',
  stage: PendingBitcoinTransactionStage.needsSignatures,
  recipient: 'tb1qrecipient',
  amount: '50000',
  amountCurrencyCode: 'sats',
  sendMax: false,
  feeSelection: FeeSelection.fastest,
  replaceByFee: true,
  psbt: 'cHNidP8=',
  createdAt: DateTime.utc(2026, 8, 14),
  updatedAt: DateTime.utc(2026, 8, 14),
);

final _utxo = WalletUtxo.bitcoin(
  walletId: 'wallet-id',
  txId: 'funding',
  vout: 0,
  scriptPubkey: Uint8List(0),
  amountSat: BigInt.from(51000),
  address: 'tb1qchange',
);

BitcoinPsbtReview _review({
  String recipient = 'tb1qrecipient',
  bool recipientWalletOwned = false,
  bool isFinalized = false,
}) => BitcoinPsbtReview(
  transactionId: 'transaction-id',
  inputs: [
    BitcoinPsbtInputReview(
      outpoint: 'funding:0',
      amountSat: BigInt.zero,
      keychain: BitcoinPolicyKeychain.external,
      localDescriptorKeyIds: const {'key-0'},
      sequence: 0xffffffff,
    ),
  ],
  outputs: [
    BitcoinPsbtOutputReview(
      index: 0,
      amountSat: BigInt.from(50000),
      address: recipient,
      scriptHex: '0014',
      isWalletOwned: recipientWalletOwned,
    ),
  ],
  feeSat: BigInt.from(1000),
  estimatedTransactionVsize: 100,
  isFinalized: isFinalized,
  lockTime: 0,
  version: 2,
);
