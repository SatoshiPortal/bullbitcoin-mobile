import 'package:bb_mobile/features/pay/domain/get_visible_payjoin_transaction_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockPayjoinSessions extends Mock implements PayjoinSessions {}

void main() {
  late _MockPayjoinSessions sessions;
  late GetVisiblePayjoinTransactionUsecase usecase;

  setUp(() {
    sessions = _MockPayjoinSessions();
    usecase = GetVisiblePayjoinTransactionUsecase(sessions);
  });

  test('returns the visible transaction id', () async {
    when(
      () => sessions.visibleTransaction('session-1'),
    ).thenAnswer((_) async => const Ok('txid-1'));

    expect(await usecase.execute('session-1'), 'txid-1');
  });

  test('returns null when nothing is visible', () async {
    when(
      () => sessions.visibleTransaction('session-1'),
    ).thenAnswer((_) async => const Ok(null));

    expect(await usecase.execute('session-1'), isNull);
  });

  test('maps a failed check to null', () async {
    when(() => sessions.visibleTransaction('session-1')).thenAnswer(
      (_) async => const Err(PayjoinUnavailableFailure('engine unavailable')),
    );

    expect(await usecase.execute('session-1'), isNull);
  });
}
