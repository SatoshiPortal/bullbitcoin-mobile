import 'package:bb_mobile/features/send/domain/usecases/get_send_payjoin_enabled_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockPayjoinPolicy extends Mock implements PayjoinPolicyAccess {}

void main() {
  late _MockPayjoinPolicy policy;

  setUp(() => policy = _MockPayjoinPolicy());

  void stubPolicy(PayjoinPolicy value) => when(
    policy.load,
  ).thenAnswer((_) async => Ok<PayjoinPolicy, PayjoinFailure>(value));

  test('off by default', () async {
    stubPolicy(PayjoinPolicy.defaults());

    expect(await GetSendPayjoinEnabledUsecase(policy).execute(), isFalse);
  });

  test('follows the send switch, not the receive one', () async {
    stubPolicy(PayjoinPolicy.defaults().copyWith(receiveEnabled: true));
    expect(await GetSendPayjoinEnabledUsecase(policy).execute(), isFalse);

    stubPolicy(PayjoinPolicy.defaults().copyWith(sendEnabled: true));
    expect(await GetSendPayjoinEnabledUsecase(policy).execute(), isTrue);
  });

  test('an unreadable policy fails closed', () async {
    when(policy.load).thenAnswer(
      (_) async =>
          const Err<PayjoinPolicy, PayjoinFailure>(PayjoinStorageFailure()),
    );

    expect(await GetSendPayjoinEnabledUsecase(policy).execute(), isFalse);
  });
}
