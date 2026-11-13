import 'package:bb_mobile/features/wizard/public/wizard_startup_facade.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/exchange_access/public/exchange_access_facade.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';

class WatchSettingsExchangeAccessUsecase {
  const WatchSettingsExchangeAccessUsecase(this._access);
  final ExchangeAccessFacade _access;

  ExchangeAccess get current => _access.current;
  Stream<ExchangeAccess> execute() => _access.watch();
}

/// Settings owns the user intention; exchange owns clearing its session.
class SetSettingsExchangeAccessUsecase {
  const SetSettingsExchangeAccessUsecase(this._access, this._exchange);
  final ExchangeAccessFacade _access;
  final ExchangeFacade _exchange;

  Future<Result<ExchangeAccessOutcome, SettingsFailure>> execute(
    bool enabled,
  ) async {
    final Result<ExchangeAccessOutcome, ExchangeAccessFailure> result;
    if (enabled) {
      result = await _access.beginActivation();
    } else {
      final cleared = await _exchange.logout();
      result = cleared
          .map((_) => ExchangeAccessOutcome.applied)
          .mapErr((_) => const ExchangeAccessIncompleteFailure());
    }
    if (result case Ok(value: ExchangeAccessOutcome.applied)) {
      try {
        await WizardStartupFacade().clearPendingExchangeChoice();
      } on Exception {
        return const Err(SettingsStorageFailure());
      }
    }
    return result.mapErr((_) => const SettingsExchangeSyncFailure());
  }

  Future<Result<void, SettingsFailure>> cancelActivation(int generation) async {
    if (generation == _access.generation &&
        _access.current.canUseAuthenticatedExchange) {
      try {
        await WizardStartupFacade().clearPendingExchangeChoice();
        return const Ok(null);
      } on Exception {
        return const Err(SettingsStorageFailure());
      }
    }
    final cancelled = await _access.cancelActivation(generation: generation);
    return cancelled
        .map((_) {})
        .mapErr((_) => const SettingsExchangeSyncFailure());
  }

  int get generation => _access.generation;
}
