import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

/// Serves Payjoin's input reservations to sync, from the Payjoin owner. Reads
/// wait for the Payjoin storage to open; a failed read stays a failure.
final class PayjoinInputReservationAdapter implements InputReservationPort {
  final PayjoinSessions _sessions;

  const PayjoinInputReservationAdapter(this._sessions);

  @override
  Future<Result<List<InputReservation>, SyncFailure>> reservations() async =>
      switch (await _sessions.inputReservations()) {
        Ok(:final value) => Ok([
          for (final reservation in value)
            InputReservation(
              outpoint: reservation.outpoint,
              protocol: 'payjoin',
              session: reservation.sessionId,
              walletId: reservation.walletId,
              network: reservation.network,
              state: reservation.status.name,
            ),
        ]),
        Err() => const Err(SyncStorageFailure()),
      };
}
