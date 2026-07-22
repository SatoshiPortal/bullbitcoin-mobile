import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';

export 'package:bb_mobile/features/sp/public/sp_facade.dart'
    show SpFailure, SpWallet;

class RefreshSpWalletForSendUsecase {
  final SpFacade _spFacade;

  RefreshSpWalletForSendUsecase(this._spFacade);

  Future<Result<SpWallet?, SpFailure>> execute() => _spFacade.refresh();
}
