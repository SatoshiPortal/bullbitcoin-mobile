import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_bitcoin_signing_plan_usecase.dart';
import 'package:meta/meta.dart';

final class ResolvedBitcoinPolicy {
  final BitcoinSigningPlan signingPlan;
  final BitcoinPolicyMaturity maturity;
  final BitcoinPolicySelection selection;
  final BitcoinPolicyPath? path;
  final bool selectionAvailable;
  final bool canBuildTransaction;

  const ResolvedBitcoinPolicy({
    required this.signingPlan,
    required this.maturity,
    required this.selection,
    required this.path,
    required this.selectionAvailable,
    required this.canBuildTransaction,
  });
}

class ResolveBitcoinPolicyUsecase {
  final GetBitcoinSigningPlanUsecase _getBitcoinSigningPlanUsecase;

  const ResolveBitcoinPolicyUsecase(this._getBitcoinSigningPlanUsecase);

  @useResult
  Future<Result<ResolvedBitcoinPolicy, BitcoinSigningFailure>> execute({
    required Wallet wallet,
    required BitcoinPolicySelection selection,
    required Set<String> selectedOutpoints,
    required Set<String> satisfiedHashlocks,
  }) async {
    final BitcoinSigningPlanDetails initial;
    switch (await _getBitcoinSigningPlanUsecase.execute(
      wallet: wallet,
      selection: selection,
      satisfiedPreimageKeys: satisfiedHashlocks,
    )) {
      case Ok(:final value):
        initial = value;
      case Err(:final failure):
        return Err(failure);
    }
    try {
      final resolvedSelection = initial.plan.policy.selectOnlyAvailablePaths(
        current: selection,
        maturity: initial.maturity,
        selectedOutpoints: selectedOutpoints,
      );
      final signingPlan = BitcoinSigningPlan.fromPolicy(
        policy: initial.plan.policy,
        signers: wallet.signers,
        selection: resolvedSelection,
        signedDescriptorKeyIdsByKeychain:
            initial.plan.signedDescriptorKeyIdsByKeychain,
        signedDescriptorKeyIdsByOutpoint:
            initial.plan.signedDescriptorKeyIdsByOutpoint,
        inputKeychainsByOutpoint: initial.plan.inputKeychainsByOutpoint,
        inputKeychains: initial.plan.inputKeychains,
        satisfiedPreimageKeys: satisfiedHashlocks,
      );

      final selectionComplete = signingPlan.policy
          .pathRequirements(resolvedSelection)
          .isEmpty;
      final selectionAvailable = signingPlan.policy.selectionIsAvailable(
        selection: resolvedSelection,
        maturity: initial.maturity,
        selectedOutpoints: selectedOutpoints,
      );
      final hasRequiredPreimages =
          selectionComplete &&
          signingPlan.policy
              .requiredHashlocks(resolvedSelection)
              .every(
                (hashlock) => satisfiedHashlocks.contains(
                  '${hashlock.type.name}:${hashlock.hash.toLowerCase()}',
                ),
              );
      final canBuildTransaction =
          selectionComplete && selectionAvailable && hasRequiredPreimages;
      final path =
          canBuildTransaction &&
              (signingPlan.policy.requiresPath ||
                  signingPlan.policy.hasTimelock)
          ? signingPlan.policy.buildPath(
              resolvedSelection,
              maturity: initial.maturity,
            )
          : null;

      return Ok(
        ResolvedBitcoinPolicy(
          signingPlan: signingPlan,
          maturity: initial.maturity,
          selection: resolvedSelection,
          path: path,
          selectionAvailable: selectionAvailable,
          canBuildTransaction: canBuildTransaction,
        ),
      );
    } on ArgumentError {
      return const Err(
        BitcoinSigningFailure(BitcoinSigningFailureKind.unsupportedPolicyPath),
      );
    }
  }
}
