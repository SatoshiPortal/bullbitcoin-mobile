/// Synthetic inputs for testing consumers of the real status session.
library;

import 'package:primitives/primitives.dart';

import 'src/status_check/domain/check_service_status_usecase.dart';
import 'src/status_check/domain/network_failure.dart';
import 'src/status_check/domain/service_status.dart';
import 'src/status_check/status_session.dart';

NetworkStatus networkStatusForTest(
  Future<Result<AllServicesStatus, NetworkFailure>> Function() check,
) => buildNetworkStatus(() => _TestStatusCheck(check));

final class _TestStatusCheck implements CheckServiceStatusUsecase {
  final Future<Result<AllServicesStatus, NetworkFailure>> Function() _check;

  _TestStatusCheck(this._check);

  @override
  Future<Result<AllServicesStatus, NetworkFailure>> execute({
    AllServicesStatus initialStatus = const AllServicesStatus(),
    void Function(AllServicesStatus status)? onUpdate,
  }) => _check();
}
