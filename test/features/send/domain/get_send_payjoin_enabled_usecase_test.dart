import 'package:bb_mobile/features/send/domain/usecases/get_send_payjoin_enabled_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockPayjoinPolicyAccess extends Mock implements PayjoinPolicyAccess {}

void main() {
  late _MockPayjoinPolicyAccess policy;
  late GetSendPayjoinEnabledUsecase usecase;

  setUp(() {
    policy = _MockPayjoinPolicyAccess();
    usecase = GetSendPayjoinEnabledUsecase(policy);
  });

  test('follows the send setting, independent of the other switches', () async {
    // Send on while receive AND trading are off: sends still payjoin.
    when(() => policy.load()).thenAnswer(
      (_) async => Ok(PayjoinPolicy.defaults().copyWith(tradingEnabled: false)),
    );
    expect(await usecase.execute(), isTrue);

    // Send off while receive AND trading are on: sends don't payjoin.
    when(() => policy.load()).thenAnswer(
      (_) async => Ok(
        PayjoinPolicy.defaults().copyWith(enabled: true, sendEnabled: false),
      ),
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
