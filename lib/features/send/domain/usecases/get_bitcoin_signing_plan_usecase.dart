import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_signing_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_psbt_review.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';

typedef BitcoinSigningPlanDetails = ({
  BitcoinPolicyMaturity maturity,
  BitcoinSigningPlan plan,
  BitcoinPsbtReview? review,
});

class GetBitcoinSigningPlanUsecase {
  final BitcoinSigningPort _bitcoinSigningPort;

  GetBitcoinSigningPlanUsecase(this._bitcoinSigningPort);

  @useResult
  Future<Result<BitcoinSigningPlanDetails, BitcoinSigningFailure>> execute({
    required Wallet wallet,
    String? psbt,
    BitcoinPolicySelection selection = const BitcoinPolicySelection.empty(),
    Set<String> satisfiedPreimageKeys = const {},
    bool allowSpentWalletInputs = false,
  }) async {
    if (!wallet.isBitcoin) {
      return const Err(
        BitcoinSigningFailure(BitcoinSigningFailureKind.unexpected),
      );
    }
    final BitcoinWalletPolicy policy;
    switch (await _bitcoinSigningPort.getPolicy(walletId: wallet.id)) {
      case Ok(:final value):
        policy = value;
      case Err(:final failure):
        return Err(failure);
    }
    final BitcoinPsbtReview? review;
    if (psbt == null) {
      review = null;
    } else {
      switch (await _bitcoinSigningPort.reviewPsbt(
        psbt,
        walletId: wallet.id,
        requireLocalOrigin: false,
        allowSpentWalletInputs: allowSpentWalletInputs,
      )) {
        case Ok(:final value):
          review = value;
        case Err(:final failure):
          return Err(failure);
      }
    }
    final maturityResult =
        policy.hasTimelock ||
            policy.requiresPath ||
            (review?.hasTimingConstraint ?? false)
        ? await _bitcoinSigningPort.getPolicyMaturity(
            walletId: wallet.id,
            includeTimeBasedLocks:
                policy.hasTimeBasedTimelock ||
                (review?.hasTimeBasedTimingConstraint ?? false),
          )
        : const Ok<BitcoinPolicyMaturity, BitcoinSigningFailure>(
            BitcoinPolicyMaturity.empty(),
          );
    final BitcoinPolicyMaturity maturity;
    switch (maturityResult) {
      case Ok(:final value):
        maturity = value;
      case Err(:final failure):
        return Err(failure);
    }
    final reviewInputs = review?.inputs ?? const <BitcoinPsbtInputReview>[];
    final effectivePreimageKeys = {
      ...?review?.satisfiedPreimageKeys,
      ...satisfiedPreimageKeys,
    };
    try {
      return Ok((
        maturity: maturity,
        review: review,
        plan: BitcoinSigningPlan.fromPolicy(
          policy: policy,
          signers: wallet.signers,
          selection: selection,
          signedDescriptorKeyIdsByKeychain:
              review?.signedDescriptorKeyIdsByKeychain ?? const {},
          signedDescriptorKeyIdsByOutpoint:
              review?.signedDescriptorKeyIdsByOutpoint ?? const {},
          inputKeychainsByOutpoint: {
            for (final input in reviewInputs) input.outpoint: ?input.keychain,
          },
          inputKeychains: reviewInputs
              .map((input) => input.keychain)
              .whereType<BitcoinPolicyKeychain>()
              .toSet(),
          satisfiedPreimageKeys: effectivePreimageKeys,
        ),
      ));
    } on ArgumentError {
      return const Err(
        BitcoinSigningFailure(BitcoinSigningFailureKind.unsupportedPolicyPath),
      );
    }
  }
}
