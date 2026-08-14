import 'package:bb_mobile/features/settings/domain/usecases/watch_payjoin_policy_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fails closed when Payjoin is unavailable', () async {
    final payjoin = Payjoin.unavailable(
      const PayjoinStorageFailure('storage unavailable'),
    );
    final usecase = WatchPayjoinPolicyUsecase(payjoin.policy);

    final policy = await usecase.execute().first;

    expect(policy.minimumAmount, PayjoinPolicy.defaults().minimumAmount);
    expect(policy.sessionLifetime, PayjoinPolicy.defaults().sessionLifetime);
    expect(policy.enabled, isFalse);
  });
}
