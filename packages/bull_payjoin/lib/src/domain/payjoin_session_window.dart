import 'package:bull_payjoin/src/domain/payjoin_policy.dart';

final class PayjoinSessionWindow {
  const PayjoinSessionWindow._();

  static Duration? forOrderDeadline(DateTime deadline, {DateTime? now}) {
    final remaining = deadline.difference(now ?? DateTime.now());
    if (remaining < PayjoinPolicy.minimumSessionLifetime) return null;
    if (remaining > PayjoinPolicy.maximumSessionLifetime) {
      return PayjoinPolicy.maximumSessionLifetime;
    }
    return Duration(seconds: remaining.inSeconds);
  }
}
