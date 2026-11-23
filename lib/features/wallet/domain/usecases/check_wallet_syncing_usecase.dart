import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';

class CheckWalletSyncingUsecase {
  final bool Function({String? walletId}) _isSyncing;

  const CheckWalletSyncingUsecase(this._isSyncing);

  @useResult
  Result<bool, WalletFailure> execute({String? walletId}) {
    try {
      return Ok(_isSyncing(walletId: walletId));
    } on Exception catch (error) {
      return Err(WalletSyncFailure(error.runtimeType.toString()));
    }
  }
}
