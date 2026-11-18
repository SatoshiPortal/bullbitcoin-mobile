import 'package:primitives/primitives.dart';

import '../domain/ports/input_reservation_port.dart';
import '../domain/sync_failure.dart';

/// Construction-time authorities: no spend request may replace either read.
/// Both callbacks must read their stores directly without reentering Sync,
/// wallet facades or the freeze queue, which the caller may already hold.
final class CombinedInputReservations implements InputReservationPort {
  final InputReservationPort _ordinary;
  final InputReservationPort? _funding;

  const CombinedInputReservations(this._ordinary, this._funding);

  @override
  Future<Result<List<InputReservation>, SyncFailure>> reservations() async {
    final ordinary = await _ordinary.reservations();
    if (ordinary case Err(:final failure)) return Err(failure);
    final funding = _funding;
    if (funding == null || identical(funding, _ordinary)) return ordinary;
    return switch (await funding.reservations()) {
      Ok(:final value) => Ok(
        List.unmodifiable([
          ...(ordinary as Ok<List<InputReservation>, SyncFailure>).value,
          ...value,
        ]),
      ),
      Err(:final failure) => Err(failure),
    };
  }
}
