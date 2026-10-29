import 'package:bb_mobile/core/swaps/domain/usecases/rescue_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/entity/restored_swap.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';
import '../settings_failure.dart';

class LoadSettingsSwapWalletsUsecase {
  final RescueSwapUsecase _rescue;
  LoadSettingsSwapWalletsUsecase({required this._rescue});
  @useResult
  Future<Result<List<Wallet>, SettingsFailure>> execute(
    RestoredSwap restored,
  ) async {
    try {
      return Ok(await _rescue.candidateWallets(restored));
    } on Exception {
      return const Err(SettingsUnexpectedFailure());
    }
  }
}
