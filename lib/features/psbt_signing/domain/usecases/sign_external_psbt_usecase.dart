import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_signing_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_psbt_review.dart';
import 'package:bb_mobile/features/psbt_signing/domain/psbt_signing_failure.dart';
import 'package:bb_mobile/features/psbt_signing/domain/psbt_signing_review.dart';
import 'package:meta/meta.dart';

class SignExternalPsbtUsecase {
  final BitcoinSigningPort _bitcoinSigningPort;

  const SignExternalPsbtUsecase(this._bitcoinSigningPort);

  @useResult
  Future<Result<PsbtSigningResult, PsbtSigningFailure>> execute(
    PsbtSigningReview review, {
    String? passphrase,
  }) async {
    if (!review.canSign) {
      return const Err(PsbtSigningMissingLocalKeyFailure());
    }

    try {
      final signedResult = await _bitcoinSigningPort.signPsbt(
        review.psbt,
        walletId: review.wallet.id,
        tryFinalize: false,
        passphrase: passphrase,
      );
      final ({String psbt, bool isFinalized}) signed;
      switch (signedResult) {
        case Ok(:final value):
          signed = value;
        case Err(:final failure):
          return Err(PsbtSigningFailure.fromBitcoinSigning(failure));
      }
      final transactionResult = await _bitcoinSigningPort.reviewPsbt(
        signed.psbt,
        walletId: review.wallet.id,
      );
      final BitcoinPsbtReview transaction;
      switch (transactionResult) {
        case Ok(:final value):
          transaction = value;
        case Err(:final failure):
          return Err(PsbtSigningFailure.fromBitcoinSigning(failure));
      }
      if (transaction.transactionId != review.transaction.transactionId) {
        return const Err(PsbtSigningWalletMismatchFailure());
      }

      final localKeyIds = review.wallet.signers
          .where((signer) => signer.signer == SignerEntity.local)
          .expand((signer) => signer.descriptorKeys)
          .map((key) => key.id)
          .toSet();
      final previousSignatures =
          review.transaction.signedDescriptorKeyIdsByOutpoint;
      final addedLocalSignature = transaction.inputs.any(
        (input) => input.signedDescriptorKeyIds
            .difference(previousSignatures[input.outpoint] ?? const {})
            .intersection(localKeyIds)
            .isNotEmpty,
      );
      if (!addedLocalSignature) {
        return const Err(PsbtSigningNoSignatureAddedFailure());
      }

      final finalizeResult = await _bitcoinSigningPort.finalizePsbt(
        signed.psbt,
      );
      final bool finalizable;
      switch (finalizeResult) {
        case Ok(:final value):
          finalizable = value.isFinalized;
        case Err(:final failure):
          return Err(PsbtSigningFailure.fromBitcoinSigning(failure));
      }
      final status = finalizable
          ? PsbtSigningResultStatus.finalizable
          : PsbtSigningResultStatus.partial;
      return Ok(PsbtSigningResult(psbt: signed.psbt, status: status));
    } on Exception catch (error, stackTrace) {
      log.severe(
        message: 'Failed to sign external PSBT',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(PsbtSigningUnexpectedFailure());
    }
  }
}
