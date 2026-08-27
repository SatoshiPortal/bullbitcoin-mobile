import 'package:bb_mobile/core/status/domain/entity/service_status.dart';
import 'package:bb_mobile/core/status/domain/usecases/check_all_service_status_usecase.dart';
import 'package:bb_mobile/core/utils/generic_extensions.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/status_check/domain/status_check_failure.dart';
import 'package:meta/meta.dart';

/// Checks the status of all external services for the default wallet's
/// network.
///
/// This is the sanitization boundary for `status_check`: it wraps two
/// still-throwing shared core use-cases (`GetWalletsUsecase`,
/// `CheckAllServiceStatusUsecase`) — `status_check` owns no repository of
/// its own, so per the rollout standard, the first layer it owns (this
/// use-case) is where the one `try/catch` lives. The raw reason is logged
/// here; only a sanitized [StatusCheckFailure] is returned.
class CheckServiceStatusUsecase {
  final CheckAllServiceStatusUsecase _checkAllServiceStatusUsecase;
  final GetWalletsUsecase _getWalletsUsecase;

  CheckServiceStatusUsecase({
    required this._checkAllServiceStatusUsecase,
    required this._getWalletsUsecase,
  });

  @useResult
  Future<Result<AllServicesStatus, StatusCheckFailure>> execute() async {
    try {
      final List<Wallet> wallets;
      try {
        wallets = await _getWalletsUsecase.execute();
      } on NoWalletsFoundException {
        return const Err(NoDefaultWalletFailure());
      }

      final defaultWallet = wallets.firstWhereOrNull((w) => w.isDefault);
      if (defaultWallet == null) {
        return const Err(NoDefaultWalletFailure());
      }

      final serviceStatus = await _checkAllServiceStatusUsecase.execute(
        network: defaultWallet.network,
      );

      return Ok(serviceStatus);
    } catch (e, st) {
      log.severe(
        message: 'Failed to check service status',
        error: e,
        trace: st,
      );
      return Err(StatusCheckUnexpectedFailure(e.toString()));
    }
  }
}
