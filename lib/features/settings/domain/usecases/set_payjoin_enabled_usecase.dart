import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_payjoin_disclaimer_shown_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/mark_payjoin_disclaimer_shown_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart' as payjoin;

class SetPayjoinEnabledUsecase {
  final payjoin.PayjoinPolicyAccess _policy;
  final GetPayjoinDisclaimerShownUsecase _getPayjoinDisclaimerShownUsecase;
  final MarkPayjoinDisclaimerShownUsecase _markPayjoinDisclaimerShownUsecase;

  SetPayjoinEnabledUsecase({
    required payjoin.PayjoinPolicyAccess payjoinPolicy,
    required this._getPayjoinDisclaimerShownUsecase,
    required this._markPayjoinDisclaimerShownUsecase,
  }) : _policy = payjoinPolicy;

  Future<Result<bool, SettingsFailure>> execute(
    bool enabled, {
    required Future<bool> Function() requestConsent,
  }) async {
    if (!enabled) {
      return _persist(false);
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
      final result = await _policy.setEnabled(enabled);
      return switch (result) {
        Ok() => Ok(enabled),
        Err() => const Err(
          SettingsStorageFailure('Failed to update Payjoin policy'),
        ),
      };
    } catch (_) {
      log.warning('Failed to persist the Payjoin setting');
      return const Err(
        SettingsStorageFailure('Failed to update Payjoin policy'),
      );
    }
  }
}
