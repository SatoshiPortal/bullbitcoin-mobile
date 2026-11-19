import 'package:background_tasks/background_tasks.dart';
import 'package:primitives/primitives.dart';

import '../domain/usecases/run_ark_background_usecase.dart';

/// Construct inside the host's BackgroundTaskSetup, registering the owned Ark
/// client with resources.onClose before the first awaited native operation.
/// Account inventory and native stores must be existing-only in that setup.
BackgroundTaskHandler arkRenewalHandler({
  required RunArkBackgroundTaskUsecase usecase,
}) => () async {
  return switch (await usecase.execute()) {
    Ok() => const BackgroundTaskExecutionResult.success(),
    Err() => const BackgroundTaskExecutionResult.retry(),
  };
};
