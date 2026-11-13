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
