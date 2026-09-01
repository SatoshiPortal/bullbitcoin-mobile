import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bull_payjoin/bull_payjoin.dart' as payjoin;

/// Toggles payjoin on regular sends.
///
/// Independent of the disclaimer-gated receive setting and the trading
/// setting, and ON by default with no consent step: the sender carries no
/// economic exposure in a payjoin — the receive side is the opt-in one.
class SetPayjoinSendEnabledUsecase {
  final payjoin.PayjoinPolicyAccess _policy;

  SetPayjoinSendEnabledUsecase({
    required payjoin.PayjoinPolicyAccess payjoinPolicy,
  }) : _policy = payjoinPolicy;

  Future<Result<bool, SettingsFailure>> execute(bool enabled) async {
    try {
      final result = await _policy.setSendEnabled(enabled);
      return switch (result) {
        Ok() => Ok(enabled),
        Err() => const Err(
          SettingsStorageFailure('Failed to update Payjoin send policy'),
        ),
      };
    } catch (_) {
      log.warning('Failed to persist the Payjoin send setting');
      return const Err(
        SettingsStorageFailure('Failed to update Payjoin send policy'),
      );
    }
  }
}
