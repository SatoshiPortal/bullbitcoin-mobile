import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/autosweep/application/run_auto_sweep_usecase.dart';

class AutosweepFacade {
  final RunAutoSweepUsecase _runAutoSweep;

  const AutosweepFacade({required this._runAutoSweep});

  Future<String?> run(Wallet syncedWallet) {
    return _runAutoSweep.execute(syncedWallet);
  }
}
