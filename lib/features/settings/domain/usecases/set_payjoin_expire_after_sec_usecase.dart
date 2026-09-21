import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';

class SetPayjoinExpireAfterSecUsecase {
  final PayjoinPolicyAccess _policy;

  SetPayjoinExpireAfterSecUsecase({required PayjoinPolicyAccess payjoinPolicy})
    : _policy = payjoinPolicy;

  @useResult
  Future<Result<void, SettingsFailure>> execute(int expireAfterSec) async {
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

    return result.mapErr(
      (failure) => SettingsStorageFailure(
        'setSessionLifetime failed: ${failure.runtimeType}',
      ),
    );
  }
}
