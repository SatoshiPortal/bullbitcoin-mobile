import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Sats;

class SetPayjoinMinAmountUsecase {
  final PayjoinPolicyAccess _policy;

  SetPayjoinMinAmountUsecase({required PayjoinPolicyAccess payjoinPolicy})
    : _policy = payjoinPolicy;

  @useResult
  Future<Result<void, SettingsFailure>> execute(int amountSat) async {
    final amount = Sats.fromInt(amountSat);
    if (amount.compareTo(PayjoinPolicy.minimumAllowedAmount) < 0 ||
        amount.compareTo(PayjoinPolicy.maximumAllowedAmount) > 0) {
      throw ArgumentError.value(
        amountSat,
        'amountSat',
        'Must be between ${PayjoinPolicy.minimumAllowedAmount} and '
            '${PayjoinPolicy.maximumAllowedAmount} sats',
      );
    }

    final result = await _policy.setMinimumAmount(amount);

    return result.mapErr(
      (failure) => SettingsStorageFailure(
        'setMinimumAmount failed: ${failure.runtimeType}',
      ),
    );
  }
}
