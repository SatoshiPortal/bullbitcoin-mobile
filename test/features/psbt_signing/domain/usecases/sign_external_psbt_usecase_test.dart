import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_signing_port.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/psbt_signing/domain/psbt_signing_failure.dart';
import 'package:bb_mobile/features/psbt_signing/domain/psbt_signing_review.dart';
import 'package:bb_mobile/features/psbt_signing/domain/usecases/sign_external_psbt_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../psbt_signing_test_fixture.dart';

class _MockBitcoinSigningPort extends Mock implements BitcoinSigningPort {}

void main() {
  test('reports a finalizable PSBT after adding a local signature', () async {
    final port = _MockBitcoinSigningPort();
    final unsigned = psbtReview(
      signedDescriptorKeyIdsByOutpoint: const {'00:0': {}, '11:1': {}},
    );
    final signed = psbtReview(
      signedDescriptorKeyIdsByOutpoint: const {
        '00:0': {'key-local'},
        '11:1': {},
      },
    );
    final review = psbtSigningReview(
      policy: singleLocalPolicy(),
      wallet: psbtSigningWallet(
        includeRemoteSigner: false,
        localRequiresPassphrase: true,
      ),
      transaction: unsigned,
    );
    when(
      () => port.signPsbt(
        'unsigned',
        walletId: 'wallet',
        tryFinalize: false,
        passphrase: 'vault passphrase',
      ),
    ).thenAnswer((_) async => const Ok((psbt: 'signed', isFinalized: false)));
    when(
      () => port.reviewPsbt('signed', walletId: 'wallet'),
    ).thenAnswer((_) async => Ok(signed));
    when(
      () => port.finalizePsbt('signed'),
    ).thenAnswer((_) async => const Ok((psbt: 'finalized', isFinalized: true)));

    final result = await SignExternalPsbtUsecase(
      port,
    ).execute(review, passphrase: 'vault passphrase');

    expect(result, isA<Ok<PsbtSigningResult, PsbtSigningFailure>>());
    final value = (result as Ok<PsbtSigningResult, PsbtSigningFailure>).value;
    expect(value.psbt, 'signed');
    expect(value.status, PsbtSigningResultStatus.finalizable);
  });

  test('rejects a signing result without a new local signature', () async {
    final port = _MockBitcoinSigningPort();
    final transaction = psbtReview();
    final review = psbtSigningReview(
      policy: singleLocalPolicy(),
      wallet: psbtSigningWallet(includeRemoteSigner: false),
      transaction: transaction,
    );
    when(
      () => port.signPsbt('unsigned', walletId: 'wallet', tryFinalize: false),
    ).thenAnswer(
      (_) async => const Ok((psbt: 'unchanged', isFinalized: false)),
    );
    when(
      () => port.reviewPsbt('unchanged', walletId: 'wallet'),
    ).thenAnswer((_) async => Ok(transaction));

    final result = await SignExternalPsbtUsecase(port).execute(review);

    expect(
      result,
      isA<Err<PsbtSigningResult, PsbtSigningFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<PsbtSigningNoSignatureAddedFailure>(),
      ),
    );
  });

  test('reports a frozen coin separately from missing PSBT data', () async {
    final port = _MockBitcoinSigningPort();
    final review = psbtSigningReview(
      policy: singleLocalPolicy(),
      wallet: psbtSigningWallet(includeRemoteSigner: false),
      transaction: psbtReview(),
    );
    when(
      () => port.signPsbt('unsigned', walletId: 'wallet', tryFinalize: false),
    ).thenAnswer(
      (_) async => const Err(
        BitcoinSigningFailure(BitcoinSigningFailureKind.frozenUtxo),
      ),
    );

    final result = await SignExternalPsbtUsecase(port).execute(review);

    expect(
      result,
      isA<Err<PsbtSigningResult, PsbtSigningFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<PsbtSigningFrozenUtxoFailure>(),
      ),
    );
  });

  test('maps the wallet signing validation failure', () async {
    final port = _MockBitcoinSigningPort();
    final review = psbtSigningReview(
      policy: singleLocalPolicy(),
      wallet: psbtSigningWallet(includeRemoteSigner: false),
      transaction: psbtReview(),
    );
    when(
      () => port.signPsbt('unsigned', walletId: 'wallet', tryFinalize: false),
    ).thenAnswer(
      (_) async => const Err(
        BitcoinSigningFailure(BitcoinSigningFailureKind.unsupportedSpendMode),
      ),
    );

    final result = await SignExternalPsbtUsecase(port).execute(review);

    expect(
      result,
      isA<Err<PsbtSigningResult, PsbtSigningFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<PsbtSigningUnsupportedSpendModeFailure>(),
      ),
    );
  });
}
