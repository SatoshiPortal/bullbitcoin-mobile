import 'package:primitives/primitives.dart';
import '../exchange_availability.dart';
import '../exchange_failure.dart';
import '../repositories/exchange_access_repository.dart';

class GuardExchangeTradingUsecase {
  const GuardExchangeTradingUsecase(this._access, this._platformAllowed);
  final ExchangeAccessRepository _access;
  final Future<bool> Function() _platformAllowed;

  Future<Result<ExchangeAvailability, ExchangeFailure>> execute() async {
    try {
      final availability = ExchangeAvailability.resolve(
        platformAllowed: await _platformAllowed(),
        access: _access.current,
      );
      if (availability == ExchangeAvailability.ready) {
        // Reconciliation uses the same queue. A displayed session is not
        // permission to trade before the active environment has been read.
        final settled = await _access.runAuthenticated(
          () async => const Ok(null),
        );
        if (settled case Err(:final failure)) {
          if (failure is! ExchangeNotAuthenticatedFailure) return Err(failure);
        }
      }
      return Ok(
        ExchangeAvailability.resolve(
          platformAllowed: await _platformAllowed(),
          access: _access.current,
        ),
      );
    } on Exception {
      return const Err(ExchangeAccountUnavailableFailure());
    }
  }
}
