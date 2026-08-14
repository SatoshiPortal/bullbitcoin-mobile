import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' show Err;

class SetPayjoinExpireAfterSecUsecase {
  final PayjoinPolicyAccess _policy;

  SetPayjoinExpireAfterSecUsecase({required PayjoinPolicyAccess payjoinPolicy})
    : _policy = payjoinPolicy;

  Future<void> execute(int expireAfterSec) async {
    final lifetime = Duration(seconds: expireAfterSec);
    if (lifetime < PayjoinPolicy.minimumSessionLifetime ||
        lifetime > PayjoinPolicy.maximumSessionLifetime) {
      throw ArgumentError.value(
        expireAfterSec,
        'expireAfterSec',
        'Must be between '
            '${PayjoinPolicy.minimumSessionLifetime.inSeconds} and '
            '${PayjoinPolicy.maximumSessionLifetime.inSeconds} seconds',
      );
    }

    final result = await _policy.setSessionLifetime(lifetime);
    if (result case Err()) {
      throw StateError('Failed to update Payjoin policy');
    }
  }
}
