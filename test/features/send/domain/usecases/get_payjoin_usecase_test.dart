import 'package:bb_mobile/features/send/domain/usecases/get_payjoin_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockPayjoinSessions extends Mock implements PayjoinSessions {}

PayjoinSenderSession _session() => PayjoinSenderSession(
  status: PayjoinStatus.requested,
  uri: 'bitcoin:bc1qaddr?amount=0.0005&pj=https://payjo.in',
  network: BitcoinNetwork.mainnet,
  walletId: 'w1',
  originalTransactionId: 'sender-orig-txid',
  amount: Sats.fromInt(50000),
  createdAt: DateTime(2026),
  expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
);

void main() {
  late _MockPayjoinSessions sessions;
  late GetPayjoinUsecase usecase;

  setUp(() {
    sessions = _MockPayjoinSessions();
    usecase = GetPayjoinUsecase(sessions);
  });

  test('returns the persisted session', () async {
    final session = _session();
    when(() => sessions.byId(session.uri)).thenAnswer((_) async => Ok(session));

    expect(await usecase.execute(session.uri), session);
  });

  test('returns null when nothing is persisted', () async {
    when(
      () => sessions.byId('bitcoin:bc1qnothing'),
    ).thenAnswer((_) async => const Ok(null));

    expect(await usecase.execute('bitcoin:bc1qnothing'), isNull);
  });

  test('maps a storage read failure to null', () async {
    when(() => sessions.byId('bitcoin:bc1qaddr')).thenAnswer(
      (_) async => const Err(PayjoinUnavailableFailure('storage locked')),
    );

    expect(await usecase.execute('bitcoin:bc1qaddr'), isNull);
  });
}
