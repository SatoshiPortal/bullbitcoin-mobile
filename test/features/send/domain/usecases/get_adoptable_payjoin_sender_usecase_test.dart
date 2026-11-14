import 'package:bb_mobile/features/send/domain/usecases/get_adoptable_payjoin_sender_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockPayjoinSessions extends Mock implements PayjoinSessions {}

const _uri = 'bitcoin:bc1qaddr?amount=0.0005&pj=https://payjo.in';

PayjoinSenderSession _session({
  PayjoinStatus status = PayjoinStatus.requested,
  String walletId = 'w1',
  int amountSat = 50000,
}) => PayjoinSenderSession(
  status: status,
  uri: _uri,
  network: BitcoinNetwork.mainnet,
  walletId: walletId,
  originalTransactionId: 'sender-orig-txid',
  amount: Sats.fromInt(amountSat),
  createdAt: DateTime(2026),
  expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
);

void main() {
  late _MockPayjoinSessions sessions;
  late GetAdoptablePayjoinSenderUsecase usecase;

  setUp(() {
    sessions = _MockPayjoinSessions();
    usecase = GetAdoptablePayjoinSenderUsecase(sessions);
  });

  Future<PayjoinSenderSession?> run() =>
      usecase.execute(sessionId: _uri, walletId: 'w1', amountSat: 50000);

  for (final status in [PayjoinStatus.requested, PayjoinStatus.proposed]) {
    test('returns this payment\'s ${status.name} session', () async {
      final session = _session(status: status);
      when(() => sessions.byId(_uri)).thenAnswer((_) async => Ok(session));

      expect(await run(), session);
    });
  }

  test('returns null when nothing is persisted', () async {
    when(() => sessions.byId(_uri)).thenAnswer((_) async => const Ok(null));

    expect(await run(), isNull);
  });

  test('maps a storage read failure to null', () async {
    when(() => sessions.byId(_uri)).thenAnswer(
      (_) async => const Err(PayjoinUnavailableFailure('storage locked')),
    );

    expect(await run(), isNull);
  });

  // The session stream never replays a terminal row, so adopting one would
  // leave the flow waiting forever.
  for (final status in [
    PayjoinStatus.expired,
    PayjoinStatus.completed,
    PayjoinStatus.aborted,
  ]) {
    test('does not return a ${status.name} session', () async {
      when(
        () => sessions.byId(_uri),
      ).thenAnswer((_) async => Ok(_session(status: status)));

      expect(await run(), isNull);
    });
  }

  // The session id is the payment link, so a live row can belong to an
  // earlier payment on the same link from another wallet or for another
  // amount. Adopting it would report this amount as sent.
  test('does not return a live session of another wallet', () async {
    when(
      () => sessions.byId(_uri),
    ).thenAnswer((_) async => Ok(_session(walletId: 'w2')));

    expect(await run(), isNull);
  });

  test('does not return a live session for another amount', () async {
    when(
      () => sessions.byId(_uri),
    ).thenAnswer((_) async => Ok(_session(amountSat: 40000)));

    expect(await run(), isNull);
  });
}
