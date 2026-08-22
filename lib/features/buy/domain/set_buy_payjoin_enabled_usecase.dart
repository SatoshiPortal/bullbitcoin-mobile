import 'package:bb_mobile/core/exchange/domain/errors/buy_error.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

class SetBuyPayjoinEnabledUsecase {
  final PayjoinPolicyAccess _policy;

  const SetBuyPayjoinEnabledUsecase(this._policy);

  Future<BuyError?> execute(bool enabled) async {
    try {
      final result = await _policy.setTradingEnabled(enabled);
      if (result case Ok()) return null;
    } catch (error, stackTrace) {
      log.warning(
        'Failed to update Payjoin trading from Buy',
        error: error,
        trace: stackTrace,
      );
    }
    return const BuyError.payjoinSettingUpdateFailed();
  }
}
