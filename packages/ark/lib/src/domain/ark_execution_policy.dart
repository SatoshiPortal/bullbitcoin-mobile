import 'package:primitives/primitives.dart';

import 'ark_wallet_failure.dart';
import 'entities/ark_account.dart';

enum ArkExecutionMode { foreground, backgroundExisting }

abstract interface class ArkStageBudget {
  bool get mayAdmitNextStage;
}

final class ArkUnlimitedStageBudget implements ArkStageBudget {
  const ArkUnlimitedStageBudget();
  @override
  bool get mayAdmitNextStage => true;
}

/// Evaluated before native stages and keyless saved-claim delivery admission.
/// Existing funds may need maintenance
/// while new payment routing is disabled; the host owns that distinction.
abstract interface class ArkExecutionPolicyPort {
  bool mayRun(ArkAccountId account, ArkExecutionMode mode);
}

/// Scoped child derivation. Implementations must never retain child words.
/// Compute the public identity through Secrets from the same admitted child.
/// Kept out of the ordinary ark.dart barrel.
abstract interface class ArkChildProviderPort {
  Future<Result<T, ArkWalletFailure>> withChild<T>(
    ArkAccountId account,
    Future<Result<T, ArkWalletFailure>> Function(
      String mnemonic,
      Fingerprint fingerprint,
    )
    action,
  );

  /// Admission for one renewal batch of an open that is already running. It
  /// is asked before every batch, never remembered from the open, so a policy
  /// change between two batches refuses the later one. It derives nothing.
  Future<Result<void, ArkWalletFailure>> admitBatch(ArkAccountId account);
}
