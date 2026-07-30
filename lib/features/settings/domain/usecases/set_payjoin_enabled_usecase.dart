import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/disable_payjoin_receivers_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_payjoin_disclaimer_shown_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/mark_payjoin_disclaimer_shown_usecase.dart';

class SetPayjoinEnabledUsecase {
  final SettingsRepository _settingsRepository;
  final GetPayjoinDisclaimerShownUsecase _getPayjoinDisclaimerShownUsecase;
  final MarkPayjoinDisclaimerShownUsecase _markPayjoinDisclaimerShownUsecase;
  final DisablePayjoinReceiversUsecase _disablePayjoinReceiversUsecase;

  SetPayjoinEnabledUsecase({
    required this._settingsRepository,
    required this._getPayjoinDisclaimerShownUsecase,
    required this._markPayjoinDisclaimerShownUsecase,
    required this._disablePayjoinReceiversUsecase,
  });

  Future<Result<bool, SettingsFailure>> execute(
    bool enabled, {
    required Future<bool> Function() requestConsent,
  }) async {
    if (!enabled) {
      final persistResult = await _persist(false);
      if (persistResult case Err(:final failure)) return Err(failure);

      try {
        await _disablePayjoinReceiversUsecase.execute();
      } catch (e, stackTrace) {
        // The user intent is already persisted and remains authoritative.
        // Unsettled receivers stay in SQLite and are retried at foreground
        // startup without accepting new requests.
        log.warning(
          'Payjoin disabled; active receiver settlement will be retried',
          error: e,
          trace: stackTrace,
        );
      }
      return const Ok(false);
    }

    final shownResult = await _getPayjoinDisclaimerShownUsecase.execute();
    switch (shownResult) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (!value) {
          bool consentGranted;
          try {
            consentGranted = await requestConsent();
          } catch (e, stackTrace) {
            log.warning(
              'Failed to present the Payjoin disclaimer',
              error: e,
              trace: stackTrace,
            );
            return Err(SettingsConsentFailure(e.toString()));
          }
          if (!consentGranted) return const Ok(false);

          final persistResult = await _persist(true);
          if (persistResult case Err(:final failure)) return Err(failure);

          final markResult = await _markPayjoinDisclaimerShownUsecase.execute();
          if (markResult case Err(:final failure)) {
            // Payjoin is enabled, but retaining the false flag is safer: the
            // disclosure will be shown again instead of being skipped.
            log.warning(
              'Failed to mark the Payjoin disclaimer as shown: '
              '${failure.logMessage}',
            );
          }
          return const Ok(true);
        }
    }

    return _persist(true);
  }

  Future<Result<bool, SettingsFailure>> _persist(bool enabled) async {
    try {
      await _settingsRepository.setPayjoinEnabled(enabled);
      return Ok(enabled);
    } catch (e, stackTrace) {
      log.warning(
        'Failed to persist the Payjoin setting',
        error: e,
        trace: stackTrace,
      );
      return Err(SettingsStorageFailure(e.toString()));
    }
  }
}
