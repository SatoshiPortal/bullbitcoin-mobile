import 'package:bb_mobile/core/exchange/domain/errors/buy_error.dart';
import 'package:bb_mobile/features/buy/domain/set_buy_payjoin_enabled_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockPayjoinPolicyAccess extends Mock implements PayjoinPolicyAccess {}

void main() {
  late _MockPayjoinPolicyAccess policy;
  late SetBuyPayjoinEnabledUsecase usecase;

  setUp(() {
    policy = _MockPayjoinPolicyAccess();
    usecase = SetBuyPayjoinEnabledUsecase(policy);
  });

  test('persists the global trading setting', () async {
    when(
      () => policy.setTradingEnabled(false),
    ).thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));

    expect(await usecase.execute(false), isNull);
    verify(() => policy.setTradingEnabled(false)).called(1);
  });

  test('maps a persistence failure to a buy error', () async {
    when(() => policy.setTradingEnabled(true)).thenAnswer(
      (_) async => const Err(PayjoinStorageFailure('storage unavailable')),
    );

    expect(
      await usecase.execute(true),
      const BuyError.payjoinSettingUpdateFailed(),
    );
  });
}
