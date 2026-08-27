import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_expire_after_sec_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Ok;

class _MockPayjoinPolicyAccess extends Mock implements PayjoinPolicyAccess {}

void main() {
  late _MockPayjoinPolicyAccess policy;
  late SetPayjoinExpireAfterSecUsecase usecase;

  setUpAll(() => registerFallbackValue(Duration.zero));

  setUp(() {
    policy = _MockPayjoinPolicyAccess();
    when(
      () => policy.setSessionLifetime(any()),
    ).thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));
    usecase = SetPayjoinExpireAfterSecUsecase(payjoinPolicy: policy);
  });

  test('persists a value within bounds', () async {
    await usecase.execute(3600);

    verify(
      () => policy.setSessionLifetime(const Duration(seconds: 3600)),
    ).called(1);
  });

  test('throws and never persists below the minimum bound', () async {
    final lifetime = PayjoinPolicy.minimumSessionLifetime.inSeconds - 1;

    await expectLater(() => usecase.execute(lifetime), throwsArgumentError);

    verifyNever(() => policy.setSessionLifetime(any()));
  });

  test('throws and never persists above the maximum bound', () async {
    final lifetime = PayjoinPolicy.maximumSessionLifetime.inSeconds + 1;

    await expectLater(() => usecase.execute(lifetime), throwsArgumentError);

    verifyNever(() => policy.setSessionLifetime(any()));
  });
}
