import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallet_failure.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallets.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/prepare_deterministic_wallets_usecase.dart';
import 'package:meta/meta.dart';

export 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallet_failure.dart';
export 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallets.dart';

class DeterministicWalletsFacade {
  final PrepareDeterministicWalletsUsecase _prepare;

  const DeterministicWalletsFacade(this._prepare);

  @useResult
  Future<Result<PreparedDeterministicWallets, DeterministicWalletFailure>>
  prepare(DeterministicWalletsRequest request) => _prepare.execute(request);

  @useResult
  Future<Result<void, DeterministicWalletFailure>> rollbackCreatedWallets(
    PreparedDeterministicWallets result,
  ) => _prepare.rollbackCreatedWallets(result);
}
