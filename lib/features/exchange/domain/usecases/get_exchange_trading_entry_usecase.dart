import 'package:meta/meta.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange_access/public/exchange_access_facade.dart';

enum ExchangeTradingEntry { allowed, authenticationRequired, unavailable }

class GetExchangeTradingEntryUsecase {
  const GetExchangeTradingEntryUsecase(this._access, this._settings);

  final ExchangeAccessFacade _access;
  final SettingsRepository _settings;

  static ExchangeTradingEntry resolve({
    required ExchangeAccess access,
    required bool platformAllowed,
  }) {
    if (!platformAllowed ||
        access.choice != ExchangeAccessChoice.enabled ||
        access.transition == ExchangeAccessTransition.disabling) {
      return ExchangeTradingEntry.unavailable;
    }
    return switch (access.session) {
      ExchangeSessionFact.authenticated => ExchangeTradingEntry.allowed,
      ExchangeSessionFact.anonymous =>
        ExchangeTradingEntry.authenticationRequired,
      _ => ExchangeTradingEntry.unavailable,
    };
  }

  @useResult
  Future<Result<ExchangeTradingEntry, ExchangeFailure>> execute({
    required bool isIOS,
  }) async {
    final generation = _access.generation;
    var platformAllowed = true;
    if (isIOS) {
      try {
        platformAllowed = (await _settings.fetch()).isSuperuser ?? false;
      } on Exception catch (_) {
        return const Err(ExchangeUnexpectedFailure());
      }
    }
    if (generation != _access.generation) {
      return const Ok(ExchangeTradingEntry.unavailable);
    }
    return Ok(
      resolve(access: _access.current, platformAllowed: platformAllowed),
    );
  }
}
