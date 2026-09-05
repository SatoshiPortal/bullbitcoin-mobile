import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/bitcoin_signer_result.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_signing_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_psbt_review.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_bitcoin_signing_plan_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/process_bitcoin_signer_result_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

const _psbt =
    'cHNidP8BAFICAAAAARERERERERERERERERERERERERERERERERERERERERERAAAAAAD9'
    '////AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAU'
    'MzMzMzMzMzMzMzMzMzMzMzMzMzMAAA==';
const _transaction =
    '020000000111111111111111111111111111111111111111111111111111111111'
    '111111110000000000fdffffff01a0860100000000001600142222222222222222'
    '22222222222222222222222200000000';

class _MockSignBitcoinTxUsecase extends Mock implements SignBitcoinTxUsecase {}

class _MockGetBitcoinSigningPlanUsecase extends Mock
    implements GetBitcoinSigningPlanUsecase {}

class _MockBitcoinSigningPort extends Mock implements BitcoinSigningPort {}

void main() {
  late _MockSignBitcoinTxUsecase signBitcoin;
  late _MockGetBitcoinSigningPlanUsecase getSigningPlan;
  late _MockBitcoinSigningPort signingPort;
  late ProcessBitcoinSignerResultUsecase usecase;

  setUp(() {
    signBitcoin = _MockSignBitcoinTxUsecase();
    getSigningPlan = _MockGetBitcoinSigningPlanUsecase();
    signingPort = _MockBitcoinSigningPort();
    usecase = ProcessBitcoinSignerResultUsecase(
      signBitcoin,
      getSigningPlan,
      signingPort,
    );
  });

  test(
    'detects and verifies a final transaction against the prepared PSBT',
    () async {
      when(
        () => signingPort.verifyFinalTransaction(
          psbt: 'current-psbt',
          transaction: _transaction,
        ),
      ).thenAnswer(
        (_) async =>
            const Ok((transaction: 'verified-transaction', txSize: 123)),
      );

      final result = await usecase.execute(
        result: _transaction,
        kind: BitcoinSignerResultKind.detect,
        currentPsbt: 'current-psbt',
        wallet: _wallet(),
        selection: const BitcoinPolicySelection.empty(),
      );

      final transaction =
          (result as Ok<ProcessedBitcoinSignerResult, BitcoinSigningFailure>)
                  .value
              as ProcessedBitcoinTransaction;
      expect(transaction.transaction, 'verified-transaction');
      expect(transaction.txSize, 123);
    },
  );

  test('rejects a transaction from a PSBT-only flow', () async {
    final result = await usecase.execute(
      result: _transaction,
      kind: BitcoinSignerResultKind.psbt,
      currentPsbt: 'current-psbt',
      wallet: _wallet(),
      selection: const BitcoinPolicySelection.empty(),
    );

    expect(
      result,
      isA<Err<ProcessedBitcoinSignerResult, BitcoinSigningFailure>>(),
    );
    verifyNever(
      () => signingPort.verifyFinalTransaction(
        psbt: any(named: 'psbt'),
        transaction: any(named: 'transaction'),
      ),
    );
  });

  test('applies the transport limit to explicitly typed results', () async {
    final result = await usecase.execute(
      result: 'x' * (maxBitcoinPsbtTransportBytes + 1),
      kind: BitcoinSignerResultKind.psbt,
      currentPsbt: 'current-psbt',
      wallet: _wallet(),
      selection: const BitcoinPolicySelection.empty(),
    );

    expect(
      result,
      isA<Err<ProcessedBitcoinSignerResult, BitcoinSigningFailure>>(),
    );
  });

  test('combines and reviews a partial PSBT', () async {
    final wallet = _wallet();
    final signingPlan = BitcoinSigningPlan.fromPolicy(
      policy: _policy(),
      signers: wallet.signers,
    );
    when(
      () => signBitcoin.execute(
        psbt: 'current-psbt',
        walletId: wallet.id,
        externalPsbt: _psbt,
        requireFinalized: false,
        tryFinalize: false,
      ),
    ).thenAnswer(
      (_) async => const Ok((
        signedPsbt: 'combined-psbt',
        txSize: 234,
        isFinalized: false,
      )),
    );
    when(
      () => getSigningPlan.execute(
        wallet: wallet,
        psbt: 'combined-psbt',
        selection: const BitcoinPolicySelection.empty(),
        satisfiedPreimageKeys: const {'sha256:aa'},
      ),
    ).thenAnswer(
      (_) async => Ok((
        plan: signingPlan,
        maturity: const BitcoinPolicyMaturity.empty(),
        review: _review(),
      )),
    );
    final result = await usecase.execute(
      result: _psbt,
      kind: BitcoinSignerResultKind.psbt,
      currentPsbt: 'current-psbt',
      wallet: wallet,
      selection: const BitcoinPolicySelection.empty(),
      satisfiedPreimageKeys: const {'sha256:aa'},
    );

    final psbt =
        (result as Ok<ProcessedBitcoinSignerResult, BitcoinSigningFailure>)
                .value
            as ProcessedBitcoinPsbt;
    expect(psbt.psbt, 'combined-psbt');
    expect(psbt.isFinalized, isFalse);
    expect(psbt.txSize, 234);
    expect(psbt.absoluteFeesSat, 1000);
    expect(psbt.signingPlan, same(signingPlan));
  });

  test('finalizes as soon as the returned PSBT satisfies the policy', () async {
    final wallet = _wallet();
    final signingPlan = BitcoinSigningPlan.fromPolicy(
      policy: _policy(),
      signers: wallet.signers,
      signedDescriptorKeyIdsByKeychain: const {
        BitcoinPolicyKeychain.external: {'key-0'},
      },
      inputKeychains: const {BitcoinPolicyKeychain.external},
    );
    when(
      () => signBitcoin.execute(
        psbt: 'current-psbt',
        walletId: wallet.id,
        externalPsbt: _psbt,
        requireFinalized: false,
        tryFinalize: false,
      ),
    ).thenAnswer(
      (_) async => const Ok((
        signedPsbt: 'combined-psbt',
        txSize: 234,
        isFinalized: false,
      )),
    );
    when(
      () => getSigningPlan.execute(
        wallet: wallet,
        psbt: 'combined-psbt',
        selection: const BitcoinPolicySelection.empty(),
        satisfiedPreimageKeys: const {},
      ),
    ).thenAnswer(
      (_) async => Ok((
        plan: signingPlan,
        maturity: const BitcoinPolicyMaturity.empty(),
        review: _review(),
      )),
    );
    when(() => signingPort.finalizePsbt('combined-psbt')).thenAnswer(
      (_) async => const Ok((psbt: 'final-psbt', isFinalized: true)),
    );
    final result = await usecase.execute(
      result: _psbt,
      kind: BitcoinSignerResultKind.psbt,
      currentPsbt: 'current-psbt',
      wallet: wallet,
      selection: const BitcoinPolicySelection.empty(),
    );

    final psbt =
        (result as Ok<ProcessedBitcoinSignerResult, BitcoinSigningFailure>)
                .value
            as ProcessedBitcoinPsbt;
    expect(psbt.psbt, 'final-psbt');
    expect(psbt.isFinalized, isTrue);
  });
}

BitcoinPsbtReview _review() => BitcoinPsbtReview(
  transactionId: 'transaction-id',
  inputs: [
    BitcoinPsbtInputReview(
      outpoint: 'funding:0',
      amountSat: BigInt.from(2000),
      keychain: BitcoinPolicyKeychain.external,
      sequence: 0xffffffff,
    ),
  ],
  outputs: [
    BitcoinPsbtOutputReview(
      index: 0,
      amountSat: BigInt.from(1000),
      address: 'tb1qrecipient',
      scriptHex: '0014',
      isWalletOwned: false,
    ),
  ],
  feeSat: BigInt.from(1000),
  estimatedTransactionVsize: 100,
  lockTime: 0,
  version: 2,
);

Wallet _wallet() => Wallet(
  origin: 'wallet',
  network: Network.bitcoinTestnet,
  signers: [
    WalletSigner.single(
      masterFingerprint: 'aabbccdd',
      xpubFingerprint: 'aabbccdd',
      xpub: 'tpub-local',
      derivationPath: "m/48'/1'/0'/2'",
      signer: SignerEntity.local,
      signerDevice: null,
    ),
  ],
  scriptType: null,
  publicDescriptor: 'wsh(pk(...))',
  balanceSat: BigInt.zero,
);

BitcoinWalletPolicy _policy() {
  BitcoinSpendingPolicy spendingPolicy() => BitcoinSpendingPolicy(
    requiresPath: false,
    root: BitcoinSignaturePolicyNode(
      id: 'local',
      key: BitcoinPolicyKey(
        kind: BitcoinPolicyKeyKind.fingerprint,
        value: 'aabbccdd',
      ),
    ),
  );
  return BitcoinWalletPolicy(
    external: spendingPolicy(),
    internal: spendingPolicy(),
  );
}
