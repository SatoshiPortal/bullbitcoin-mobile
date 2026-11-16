import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_failure.dart';
import 'read_ark_usecase.dart';
import 'update_ark_expiry_warning_usecase.dart';

/// The host opens an existing-only native client with stage-budget admission.
/// This usecase awaits its pass through settlement: no timeout can close the
/// native writer while an admitted stage is still running.
final class RunArkBackgroundUsecase {
  final SynchronizeArkUsecase _synchronize;
  final UpdateArkExpiryWarningUsecase _warnings;
  const RunArkBackgroundUsecase(this._synchronize, this._warnings);

  Future<Result<void, ArkFailure>> execute(ArkAccountId account) async {
    switch (await _synchronize.execute(account, renew: true)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (value.snapshot.account != account) {
          return const Err(ArkUnexpectedFailure());
        }
        if (!value.completedStages.contains(ArkStage.vtxos) ||
            value.failedStageKinds.contains(ArkStage.vtxos)) {
          return const Err(ArkServiceUnavailableFailure());
        }
        final reminder = await _warnings.execute(value.snapshot);
        if (reminder case Err(:final failure)) return Err(failure);
        return value.failedStages.isEmpty && value.failedStageKinds.isEmpty
            ? const Ok(null)
            : const Err(ArkServiceUnavailableFailure());
    }
  }
}
