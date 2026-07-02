import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/autosweep/domain/autosweep_result.dart';
import 'package:bb_mobile/features/autosweep/domain/usecases/run_auto_sweep_usecase.dart';

export 'package:bb_mobile/features/autosweep/domain/autosweep_error.dart';
export 'package:bb_mobile/features/autosweep/domain/autosweep_result.dart';

class AutosweepFacade {
  final RunAutoSweepUsecase _runAutoSweep;

  const AutosweepFacade({required this._runAutoSweep});

  Future<AutosweepResult> run(Wallet syncedWallet) {
    return _runAutoSweep.execute(syncedWallet);
  }
}
