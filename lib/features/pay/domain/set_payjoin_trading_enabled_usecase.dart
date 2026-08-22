import 'package:bb_mobile/core/exchange/domain/errors/pay_error.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

class SetPayjoinTradingEnabledUsecase {
  final PayjoinPolicyAccess _policy;

  const SetPayjoinTradingEnabledUsecase(this._policy);

  Future<PayError?> execute(bool enabled) async {
    try {
      final result = await _policy.setTradingEnabled(enabled);
      if (result case Ok()) return null;
    } catch (error, stackTrace) {
      log.warning(
        'Failed to update Payjoin trading from Pay',
        error: error,
        trace: stackTrace,
      );
    }
    return const PayError.payjoinSettingUpdateFailed();
  }
}
