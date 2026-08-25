import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/bitcoin_signer_result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_signing_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_psbt_review.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/psbt_signing/domain/psbt_signing_failure.dart';
import 'package:bb_mobile/features/psbt_signing/domain/psbt_signing_review.dart';
import 'package:meta/meta.dart';

class ReviewPsbtUsecase {
  final GetWalletUsecase _getWalletUsecase;
  final BitcoinSigningPort _bitcoinSigningPort;

  const ReviewPsbtUsecase({
    required this._getWalletUsecase,
    required this._bitcoinSigningPort,
  });

  @useResult
  Future<Result<PsbtSigningReview, PsbtSigningFailure>> execute({
    required String walletId,
    required String psbt,
  }) async {
    try {
      final wallet = await _getWalletUsecase.execute(walletId);
      if (wallet == null || !wallet.isBitcoin) {
        return const Err(PsbtSigningWalletUnavailableFailure());
      }
      if (!wallet.signers.any(
        (signer) => signer.signer == SignerEntity.local,
      )) {
        return const Err(PsbtSigningMissingLocalKeyFailure());
      }

      final normalizedPsbt = normalizeBitcoinPsbt(psbt);
      final transactionResult = await _bitcoinSigningPort.reviewPsbt(
        normalizedPsbt,
        walletId: walletId,
      );
      final BitcoinPsbtReview transaction;
      switch (transactionResult) {
        case Ok(:final value):
          transaction = value;
        case Err(:final failure):
          return Err(PsbtSigningFailure.fromBitcoinSigning(failure));
      }
      final policyResult = await _bitcoinSigningPort.getPolicy(
        walletId: walletId,
      );
      final BitcoinWalletPolicy policy;
      switch (policyResult) {
        case Ok(:final value):
          policy = value;
        case Err(:final failure):
          return Err(PsbtSigningFailure.fromBitcoinSigning(failure));
      }
      var maturity = const BitcoinPolicyMaturity.empty();
      if (transaction.hasTimingConstraint) {
        final maturityResult = await _bitcoinSigningPort.getPolicyMaturity(
          walletId: walletId,
          includeTimeBasedLocks: transaction.hasTimeBasedTimingConstraint,
        );
        switch (maturityResult) {
          case Ok(:final value):
            maturity = value;
          case Err(:final failure):
            return Err(PsbtSigningFailure.fromBitcoinSigning(failure));
        }
      }
      final transactionTimingVerified = transaction.timingIsSatisfied(maturity);
      final review = PsbtSigningReview(
        wallet: wallet,
        psbt: normalizedPsbt,
        transaction: transaction,
        policy: policy,
        transactionTimingVerified: transactionTimingVerified,
        blockingTimingActivation: transactionTimingVerified
            ? null
            : transaction.blockingTimingActivation(maturity),
      );
      return Ok(review);
    } on FormatException {
      return const Err(PsbtSigningInvalidPsbtFailure());
    } on Exception catch (error, stackTrace) {
      log.severe(
        message: 'Failed to review external PSBT',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(PsbtSigningUnexpectedFailure());
    }
  }
}
