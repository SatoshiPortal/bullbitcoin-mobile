import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bull_payjoin/bull_payjoin.dart' as payjoin;

/// Toggles payjoin for Bull Bitcoin exchange trades (buy/sell/pay orders).
///
/// Independent of the disclaimer-gated global payjoin setting and ON by
/// default: the exchange API is a trusted counterparty to the trade itself,
/// so no disclaimer/consent step is involved. Also written through from the
/// per-order payjoin toggle in the buy/sell/pay flows — flipping that switch
/// IS flipping this setting.
class SetPayjoinTradingEnabledUsecase {
  final payjoin.PayjoinPolicyAccess _policy;

  SetPayjoinTradingEnabledUsecase({
    required payjoin.PayjoinPolicyAccess payjoinPolicy,
  }) : _policy = payjoinPolicy;

  Future<Result<bool, SettingsFailure>> execute(bool enabled) async {
    try {
      final result = await _policy.setTradingEnabled(enabled);
      return switch (result) {
        Ok() => Ok(enabled),
        Err() => const Err(
          SettingsStorageFailure('Failed to update Payjoin trading policy'),
        ),
      };
    } catch (_) {
      log.warning('Failed to persist the Payjoin trading setting');
      return const Err(
        SettingsStorageFailure('Failed to update Payjoin trading policy'),
      );
    }
  }
}
