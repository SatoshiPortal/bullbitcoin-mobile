import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_signing_port.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/psbt_signing/domain/psbt_signing_failure.dart';
import 'package:bb_mobile/features/psbt_signing/domain/psbt_signing_review.dart';
import 'package:bb_mobile/features/psbt_signing/domain/usecases/review_psbt_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../psbt_signing_test_fixture.dart';

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class _MockBitcoinSigningPort extends Mock implements BitcoinSigningPort {}

void main() {
  late _MockGetWalletUsecase getWalletUsecase;
  late _MockBitcoinSigningPort signingPort;
  late ReviewPsbtUsecase usecase;

  setUp(() {
    getWalletUsecase = _MockGetWalletUsecase();
    signingPort = _MockBitcoinSigningPort();
    usecase = ReviewPsbtUsecase(
      getWalletUsecase: getWalletUsecase,
      bitcoinSigningPort: signingPort,
    );
  });

  test('allows signing without choosing a spending path', () async {
    final wallet = psbtSigningWallet();
    final transaction = psbtReview();
    final policy = absoluteChoicePolicy();
    when(
      () => getWalletUsecase.execute(wallet.id),
    ).thenAnswer((_) async => wallet);
    when(
      () => signingPort.reviewPsbt(testPsbtBase64, walletId: wallet.id),
    ).thenAnswer((_) async => Ok(transaction));
    when(
      () => signingPort.getPolicy(walletId: wallet.id),
    ).thenAnswer((_) async => Ok(policy));
    final result = await usecase.execute(
      walletId: wallet.id,
      psbt: testPsbtBase64,
    );

    expect(result, isA<Ok<PsbtSigningReview, PsbtSigningFailure>>());
    final review = (result as Ok<PsbtSigningReview, PsbtSigningFailure>).value;
    expect(review.canSign, isTrue);
  });

  test('does not offer an unrelated local key for an input', () async {
    final wallet = psbtSigningWallet(remoteSignerIsLocal: true);
    final transaction = psbtReview(signedDescriptorKeyIds: const {'key-local'});
    when(
      () => getWalletUsecase.execute(wallet.id),
    ).thenAnswer((_) async => wallet);
    when(
      () => signingPort.reviewPsbt(testPsbtBase64, walletId: wallet.id),
    ).thenAnswer((_) async => Ok(transaction));
    when(
      () => signingPort.getPolicy(walletId: wallet.id),
    ).thenAnswer((_) async => Ok(singleLocalPolicy()));

    final result = await usecase.execute(
      walletId: wallet.id,
      psbt: testPsbtBase64,
    );

    final review = (result as Ok<PsbtSigningReview, PsbtSigningFailure>).value;
    expect(review.canSign, isFalse);
  });

  test('identifies a protected local key before signing', () async {
    final wallet = psbtSigningWallet(localRequiresPassphrase: true);
    final transaction = psbtReview();
    when(
      () => getWalletUsecase.execute(wallet.id),
    ).thenAnswer((_) async => wallet);
    when(
      () => signingPort.reviewPsbt(testPsbtBase64, walletId: wallet.id),
    ).thenAnswer((_) async => Ok(transaction));
    when(
      () => signingPort.getPolicy(walletId: wallet.id),
    ).thenAnswer((_) async => Ok(singleLocalPolicy()));

    final result = await usecase.execute(
      walletId: wallet.id,
      psbt: testPsbtBase64,
    );

    final review = (result as Ok<PsbtSigningReview, PsbtSigningFailure>).value;
    expect(review.requiresPassphrase, isTrue);
  });

  test('rejects a wallet without a local signer', () async {
    final wallet = psbtSigningWallet(hasLocalSigner: false);
    when(
      () => getWalletUsecase.execute(wallet.id),
    ).thenAnswer((_) async => wallet);

    final result = await usecase.execute(
      walletId: wallet.id,
      psbt: testPsbtBase64,
    );

    expect(
      result,
      isA<Err<PsbtSigningReview, PsbtSigningFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<PsbtSigningMissingLocalKeyFailure>(),
      ),
    );
  });

  test(
    'reports a future transaction locktime without blocking signing',
    () async {
      final wallet = psbtSigningWallet();
      final transaction = psbtReview(lockTime: 101);
      when(
        () => getWalletUsecase.execute(wallet.id),
      ).thenAnswer((_) async => wallet);
      when(
        () => signingPort.reviewPsbt(testPsbtBase64, walletId: wallet.id),
      ).thenAnswer((_) async => Ok(transaction));
      when(
        () => signingPort.getPolicy(walletId: wallet.id),
      ).thenAnswer((_) async => Ok(singleLocalPolicy()));
      when(
        () => signingPort.getPolicyMaturity(
          walletId: wallet.id,
          includeTimeBasedLocks: false,
        ),
      ).thenAnswer((_) async => Ok(psbtPolicyMaturity()));

      final result = await usecase.execute(
        walletId: wallet.id,
        psbt: testPsbtBase64,
      );

      final review =
          (result as Ok<PsbtSigningReview, PsbtSigningFailure>).value;
      expect(review.transactionTimingVerified, isFalse);
      expect(
        review.blockingTimingActivation?.type,
        BitcoinPolicyActivationType.absoluteBlock,
      );
      expect(review.blockingTimingActivation?.value, 101);
      expect(review.canSign, isTrue);
    },
  );

  test('reports an immature input sequence without blocking signing', () async {
    final wallet = psbtSigningWallet();
    final transaction = psbtReview(sequence: 10);
    when(
      () => getWalletUsecase.execute(wallet.id),
    ).thenAnswer((_) async => wallet);
    when(
      () => signingPort.reviewPsbt(testPsbtBase64, walletId: wallet.id),
    ).thenAnswer((_) async => Ok(transaction));
    when(
      () => signingPort.getPolicy(walletId: wallet.id),
    ).thenAnswer((_) async => Ok(singleLocalPolicy()));
    when(
      () => signingPort.getPolicyMaturity(
        walletId: wallet.id,
        includeTimeBasedLocks: false,
      ),
    ).thenAnswer((_) async => Ok(psbtPolicyMaturity(confirmations: 9)));

    final result = await usecase.execute(
      walletId: wallet.id,
      psbt: testPsbtBase64,
    );

    final review = (result as Ok<PsbtSigningReview, PsbtSigningFailure>).value;
    expect(review.transactionTimingVerified, isFalse);
    expect(
      review.blockingTimingActivation?.type,
      BitcoinPolicyActivationType.relativeBlocks,
    );
    expect(review.blockingTimingActivation?.value, 1);
    expect(review.canSign, isTrue);
  });
}
