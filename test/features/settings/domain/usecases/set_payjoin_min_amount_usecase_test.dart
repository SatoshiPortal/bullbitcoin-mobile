import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_min_amount_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Ok, Sats;

class _MockPayjoinPolicyAccess extends Mock implements PayjoinPolicyAccess {}

void main() {
  late _MockPayjoinPolicyAccess policy;
  late SetPayjoinMinAmountUsecase usecase;

  setUpAll(() => registerFallbackValue(Sats.zero));

  setUp(() {
    policy = _MockPayjoinPolicyAccess();
    when(
      () => policy.setMinimumAmount(any()),
    ).thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));
    usecase = SetPayjoinMinAmountUsecase(payjoinPolicy: policy);
  });

  test('persists a value within bounds', () async {
    expect(await usecase.execute(50000), isA<Ok<void, SettingsFailure>>());

    verify(() => policy.setMinimumAmount(Sats.fromInt(50000))).called(1);
  });

  test('persists the exact lower bound', () async {
    final amount = PayjoinPolicy.minimumAllowedAmount.value.toInt();

    expect(await usecase.execute(amount), isA<Ok<void, SettingsFailure>>());

    verify(() => policy.setMinimumAmount(Sats.fromInt(amount))).called(1);
  });

  test('persists the exact upper bound', () async {
    final amount = PayjoinPolicy.maximumAllowedAmount.value.toInt();

    expect(await usecase.execute(amount), isA<Ok<void, SettingsFailure>>());

    verify(() => policy.setMinimumAmount(Sats.fromInt(amount))).called(1);
  });

  test('throws and never persists below the minimum bound', () async {
    final amount = PayjoinPolicy.minimumAllowedAmount.value.toInt() - 1;

    await expectLater(() => usecase.execute(amount), throwsArgumentError);

    verifyNever(() => policy.setMinimumAmount(any()));
  });

  test('throws and never persists above the maximum bound', () async {
    final amount = PayjoinPolicy.maximumAllowedAmount.value.toInt() + 1;

    await expectLater(() => usecase.execute(amount), throwsArgumentError);

    verifyNever(() => policy.setMinimumAmount(any()));
  });
}
