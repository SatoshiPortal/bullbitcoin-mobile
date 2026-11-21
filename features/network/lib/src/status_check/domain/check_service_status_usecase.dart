import 'service_status.dart';
import 'check_all_service_status_usecase.dart';

import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import 'status_check_failure.dart';

import 'package:meta/meta.dart';

/// Checks the status of all external services for the default wallet's
/// network.
///
/// This is the sanitization boundary for `status_check`: it wraps two
/// operations (loading the default network and checking its services) — `status_check` owns no repository of
/// its own, so per the rollout standard, the first layer it owns (this
/// use-case) is where the one `try/catch` lives. The raw reason is logged
/// here; only a sanitized [StatusCheckFailure] is returned.
class CheckServiceStatusUsecase {
  final CheckAllServiceStatusUsecase _checkAllServiceStatusUsecase;
  final Future<Result<NetworkEnv?, Failure>> Function() _readDefaultNetwork;

  CheckServiceStatusUsecase({
    required this._checkAllServiceStatusUsecase,
    required this._readDefaultNetwork,
  });

  @useResult
  Future<Result<AllServicesStatus, StatusCheckFailure>> execute({
    AllServicesStatus initialStatus = const AllServicesStatus(),
    void Function(AllServicesStatus status)? onUpdate,
  }) async {
    try {
      final NetworkEnv network;
      switch (await _readDefaultNetwork()) {
        case Ok(value: final value?):
          network = value;
        case Ok():
          return const Err(NoDefaultWalletFailure());
        case Err(:final failure):
          log.warning('status check: ${failure.logMessage}');
          return Err(
            StatusCheckUnexpectedFailure('wallets: ${failure.runtimeType}'),
          );
      }

      final serviceStatus = await _checkAllServiceStatusUsecase.execute(
        network: network,
        initialStatus: initialStatus,
        onUpdate: onUpdate,
      );

      return Ok(serviceStatus);
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to check service status',
        error: e,
        trace: st,
      );
      return Err(StatusCheckUnexpectedFailure(e.toString()));
    }
  }
}
