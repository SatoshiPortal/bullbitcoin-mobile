import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/address_view/domain/address_view_failure.dart';
import 'package:meta/meta.dart';

class CheckWalletIsLiquidUsecase {
  final GetWalletUsecase _getWalletUsecase;

  const CheckWalletIsLiquidUsecase({required this._getWalletUsecase});

  @useResult
  Future<Result<bool, AddressViewFailure>> execute(String walletId) async {
    try {
      final wallet = await _getWalletUsecase.execute(walletId);
      if (wallet == null) return const Err(AddressViewWalletNotFoundFailure());

      return Ok(wallet.isLiquid);
    } catch (e, st) {
      log.warning(
        'Failed to resolve the wallet kind for the address view',
        error: e,
        trace: st,
      );
      return Err(AddressViewUnexpectedFailure(e.runtimeType.toString()));
    }
  }
}
