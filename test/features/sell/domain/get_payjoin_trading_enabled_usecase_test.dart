import 'package:bb_mobile/features/sell/domain/get_payjoin_trading_enabled_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockPayjoinPolicyAccess extends Mock implements PayjoinPolicyAccess {}

void main() {
  late _MockPayjoinPolicyAccess policy;
  late GetPayjoinTradingEnabledUsecase usecase;

  setUp(() {
    policy = _MockPayjoinPolicyAccess();
    usecase = GetPayjoinTradingEnabledUsecase(policy);
  });

  test('returns the persisted trading setting', () async {
    when(() => policy.load()).thenAnswer(
      (_) async => Ok(PayjoinPolicy.defaults().copyWith(tradingEnabled: false)),
    );

    expect(await usecase.execute(), isFalse);
  });

  test('fails closed when the policy cannot be loaded', () async {
    when(() => policy.load()).thenAnswer(
      (_) async => const Err(PayjoinStorageFailure('storage unavailable')),
    );

    expect(await usecase.execute(), isFalse);
  });
}
