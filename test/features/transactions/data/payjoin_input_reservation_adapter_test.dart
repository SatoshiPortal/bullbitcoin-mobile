import 'package:bb_mobile/features/wallet/data/payjoin_input_reservation_adapter.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

class _MockPayjoinSessions extends Mock implements PayjoinSessions {}

void main() {
  late _MockPayjoinSessions sessions;
  late PayjoinInputReservationAdapter adapter;

  setUp(() {
    sessions = _MockPayjoinSessions();
    adapter = PayjoinInputReservationAdapter(sessions);
  });

  test('each reservation reaches sync with its owning session', () async {
    when(() => sessions.inputReservations()).thenAnswer(
      (_) async => const Ok([
        PayjoinInputReservation(
          outpoint: (txId: 'aa', vout: 1),
          sessionId: 'receiver-1',
          role: PayjoinParty.recipient,
          walletId: 'wallet-1',
          network: BitcoinNetwork.testnet,
          status: PayjoinStatus.proposed,
        ),
      ]),
    );

    final result = await adapter.reservations();

    final reservation = switch (result) {
      Ok(:final value) => value.single,
      Err(:final failure) => fail('unexpected $failure'),
    };
    expect(reservation.outpoint, (txId: 'aa', vout: 1));
    expect(reservation.protocol, 'payjoin');
    expect(reservation.session, 'receiver-1');
    expect(reservation.walletId, 'wallet-1');
    expect(reservation.network, BitcoinNetwork.testnet);
    expect(reservation.state, 'proposed');
  });

  test(
    'an unreadable Payjoin store is a failure, never no reservation',
    () async {
      when(
        () => sessions.inputReservations(),
      ).thenAnswer((_) async => const Err(PayjoinStorageFailure('unreadable')));

      expect(
        await adapter.reservations(),
        isA<Err<List<InputReservation>, SyncFailure>>(),
      );
    },
  );
}
