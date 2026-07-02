import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/autosweep/public/autosweep_facade.dart';

export 'package:bb_mobile/features/autosweep/public/autosweep_facade.dart'
    show
        AutosweepError,
        AutosweepFailed,
        AutosweepResult,
        AutosweepSkipReason,
        AutosweepSkipped,
        AutosweepSwept;

class RunWalletAutoSweepUsecase {
  final AutosweepFacade _autosweep;

  const RunWalletAutoSweepUsecase({required this._autosweep});

  Future<AutosweepResult> execute(Wallet syncedWallet) {
    return _autosweep.run(syncedWallet);
  }
}
