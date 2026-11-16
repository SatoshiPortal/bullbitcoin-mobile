import 'package:bb_mobile/features/send/domain/usecases/broadcast_payjoin_original_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockPayjoinSender extends Mock implements PayjoinSender {}

PayjoinSenderSession _session() => PayjoinSenderSession(
  status: PayjoinStatus.aborted,
  uri: 'bitcoin:bc1qaddr?amount=0.0005&pj=https://payjo.in',
  network: BitcoinNetwork.mainnet,
  walletId: 'w1',
  originalTransactionId: 'sender-orig-txid',
  amount: Sats.fromInt(50000),
  createdAt: DateTime(2026),
  expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
);

void main() {
  late _MockPayjoinSender sender;
  late List<Duration> waits;
  late BroadcastPayjoinOriginalUsecase usecase;

  setUp(() {
    sender = _MockPayjoinSender();
    waits = [];
    usecase = BroadcastPayjoinOriginalUsecase(
      sender,
      (d) async => waits.add(d),
    );
  });

  test('returns the settled session of an accepted broadcast', () async {
    final settled = _session();
    when(() => sender.broadcastOriginal('session-1'))
        .thenAnswer((_) async => Ok(settled));

    expect(await usecase.execute('session-1'), settled);
    expect(waits, isEmpty);
  });

  test('reports a refused broadcast as null without failing', () async {
    when(() => sender.broadcastOriginal('session-1')).thenAnswer(
      (_) async => const Err(PayjoinBroadcastFailure('Broadcast failed')),
    );

    expect(await usecase.execute('session-1'), isNull);
    verify(() => sender.broadcastOriginal('session-1')).called(1);
  });

  test('asks again while the wallet is only busy', () async {
    final settled = _session();
    var calls = 0;
    when(() => sender.broadcastOriginal('session-1')).thenAnswer((_) async {
      calls++;
      return calls < 3
          ? const Err(PayjoinSpendBlockedFailure(busy: true))
          : Ok(settled);
    });

    expect(await usecase.execute('session-1'), settled);
    expect(calls, 3);
    expect(waits, [
      BroadcastPayjoinOriginalUsecase.busyRetryDelay,
      BroadcastPayjoinOriginalUsecase.busyRetryDelay,
    ]);
  });

  test('gives up after the busy retries', () async {
    when(() => sender.broadcastOriginal('session-1')).thenAnswer(
      (_) async => const Err(PayjoinSpendBlockedFailure(busy: true)),
    );

    expect(await usecase.execute('session-1'), isNull);
    verify(() => sender.broadcastOriginal('session-1'))
        .called(BroadcastPayjoinOriginalUsecase.busyRetries + 1);
  });

  test('a spend blocked for an observation is not retried', () async {
    when(() => sender.broadcastOriginal('session-1'))
        .thenAnswer((_) async => const Err(PayjoinSpendBlockedFailure()));

    expect(await usecase.execute('session-1'), isNull);
    verify(() => sender.broadcastOriginal('session-1')).called(1);
    expect(waits, isEmpty);
  });
}
