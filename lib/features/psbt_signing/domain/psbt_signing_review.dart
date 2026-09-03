import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_psbt_review.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

final class PsbtSigningReview {
  final Wallet wallet;
  final String psbt;
  final BitcoinPsbtReview transaction;
  final BitcoinWalletPolicy policy;
  final bool transactionTimingVerified;
  final BitcoinPolicyActivation? blockingTimingActivation;

  const PsbtSigningReview({
    required this.wallet,
    required this.psbt,
    required this.transaction,
    required this.policy,
    required this.transactionTimingVerified,
    this.blockingTimingActivation,
  });

  bool get canSign => transaction.inputs.any(
    (input) => input.localDescriptorKeyIds
        .difference(input.signedDescriptorKeyIds)
        .isNotEmpty,
  );

  bool get requiresPassphrase {
    final unsignedLocalKeyIds = transaction.inputs
        .expand(
          (input) => input.localDescriptorKeyIds.difference(
            input.signedDescriptorKeyIds,
          ),
        )
        .toSet();
    return wallet.signers
        .expand((signer) => signer.descriptorKeys)
        .any(
          (key) =>
              unsignedLocalKeyIds.contains(key.id) && key.requiresPassphrase,
        );
  }
}

enum PsbtSigningResultStatus { partial, finalizable }

final class PsbtSigningResult {
  final String psbt;
  final PsbtSigningResultStatus status;

  const PsbtSigningResult({required this.psbt, required this.status});
}
