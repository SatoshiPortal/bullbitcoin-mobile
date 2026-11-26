import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'check_all_service_status_usecase.dart';
import 'network_failure.dart';
import 'service_status.dart';

/// Captures the default wallet's network and checks its services.
/// This boundary logs probe exceptions and returns a sanitized [NetworkFailure].
class CheckServiceStatusUsecase {
  final CheckAllServiceStatusUsecase _checkAllServiceStatusUsecase;
  final Future<Result<NetworkEnv?, Failure>> Function() _readDefaultNetwork;

  CheckServiceStatusUsecase({
    required this._checkAllServiceStatusUsecase,
    required this._readDefaultNetwork,
  });

  @useResult
  Future<Result<AllServicesStatus, NetworkFailure>> execute({
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
          return const Err(NetworkUnexpectedFailure());
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
      return const Err(NetworkUnexpectedFailure());
    }
  }
}
