import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' show Err, Sats;

class SetPayjoinMinAmountUsecase {
  final PayjoinPolicyAccess _policy;

  SetPayjoinMinAmountUsecase({required PayjoinPolicyAccess payjoinPolicy})
    : _policy = payjoinPolicy;

  Future<void> execute(int amountSat) async {
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
    if (result case Err()) {
      throw StateError('Failed to update Payjoin policy');
    }
  }
}
