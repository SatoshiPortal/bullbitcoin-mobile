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
  late BroadcastPayjoinOriginalUsecase usecase;

  setUp(() {
    sender = _MockPayjoinSender();
    usecase = BroadcastPayjoinOriginalUsecase(sender);
  });

  test('reports an accepted broadcast', () async {
    when(
      () => sender.broadcastOriginal('session-1'),
    ).thenAnswer((_) async => Ok(_session()));

    expect(await usecase.execute('session-1'), isTrue);
  });

  test('reports a refused broadcast without failing', () async {
    when(() => sender.broadcastOriginal('session-1')).thenAnswer(
      (_) async => const Err(PayjoinBroadcastFailure('Broadcast failed')),
    );

    expect(await usecase.execute('session-1'), isFalse);
  });
}
