import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/autosweep/public/autosweep_facade.dart';

class RunWalletAutoSweepUsecase {
  final AutosweepFacade _autosweep;

  const RunWalletAutoSweepUsecase({required this._autosweep});

  Future<String?> execute(Wallet syncedWallet) {
    return _autosweep.run(syncedWallet);
  }
}
