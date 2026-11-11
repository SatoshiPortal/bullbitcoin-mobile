import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:meta/meta.dart';

class CheckSwapSpendAdmissionUsecase {
  final WalletFacade _wallet;

  const CheckSwapSpendAdmissionUsecase(this._wallet);

  @useResult
  Future<Result<void, SwapFailure>> execute(String walletId) async {
    final status = await _wallet.spendStatus(walletId);
    if (status != BitcoinSpendStatus.ready) {
      return Err(SwapSpendBlockedFailure(status));
    }
    return const Ok(null);
  }
}
