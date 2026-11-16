import 'package:ark/ark.dart';
import 'package:background_tasks/background_tasks.dart';
import 'package:primitives/primitives.dart';

import '../domain/ark_failure.dart';
import '../domain/usecases/run_ark_background_usecase.dart';

/// Construct inside the host's BackgroundTaskSetup, registering the owned Ark
/// client with resources.onClose before the first awaited native operation.
/// Account inventory and native stores must be existing-only in that setup.
BackgroundTaskHandler arkRenewalHandler({
  required List<ArkAccountId> accounts,
  required RunArkBackgroundUsecase usecase,
}) => () async {
  var retry = false;
  for (final account in accounts) {
    switch (await usecase.execute(account)) {
      case Ok():
        break;
      case Err(
        failure: ArkInvalidRequestFailure() || ArkNetworkUnavailableFailure(),
      ):
        break;
      case Err():
        retry = true;
    }
  }
  return retry
      ? const BackgroundTaskExecutionResult.retry()
      : const BackgroundTaskExecutionResult.success();
};
