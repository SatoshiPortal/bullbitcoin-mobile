import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallet_failure.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallets.dart';
import 'package:meta/meta.dart';

export 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallet_failure.dart';
export 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallets.dart';

/// The only supported consumer boundary for deterministic wallet creation.
///
/// Requests and results contain product metadata and public descriptors only.
/// Derived mnemonic words, seed bytes, and extended private keys remain inside
/// the feature.
typedef _PrepareWallets =
    Future<Result<PreparedDeterministicWallets, DeterministicWalletFailure>>
    Function(DeterministicWalletsRequest request);
typedef _RollbackWallets =
    Future<Result<void, DeterministicWalletFailure>> Function(
      PreparedDeterministicWallets result,
    );

class DeterministicWalletsFacade {
  final _PrepareWallets _prepareWallets;
  final _RollbackWallets _rollbackWallets;

  const DeterministicWalletsFacade({
    required this._prepareWallets,
    required this._rollbackWallets,
  });

  @useResult
  Future<Result<PreparedDeterministicWallets, DeterministicWalletFailure>>
  prepare(DeterministicWalletsRequest request) => _prepareWallets(request);

  @useResult
  Future<Result<void, DeterministicWalletFailure>> rollbackCreatedWallets(
    PreparedDeterministicWallets result,
  ) => _rollbackWallets(result);
}
