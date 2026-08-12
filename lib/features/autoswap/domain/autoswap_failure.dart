import 'package:bb_mobile/core/failures/failure.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';

sealed class AutoswapFailure extends Failure {
  const AutoswapFailure([super.logMessage]);
}

/// The stored settings, the wallet list or the app settings could not be read,
/// so the form cannot be populated.
final class AutoswapSettingsUnavailableFailure extends AutoswapFailure {
  const AutoswapSettingsUnavailableFailure([super.logMessage]);
}

/// Writing the settings failed.
final class AutoswapSettingsSaveFailure extends AutoswapFailure {
  const AutoswapSettingsSaveFailure([super.logMessage]);
}

/// Auto swap is being enabled without a wallet to send the swapped funds to.
/// Only enforced while enabling — disabling needs no recipient.
final class AutoswapRecipientWalletRequiredFailure extends AutoswapFailure {
  const AutoswapRecipientWalletRequiredFailure();
}

/// The target balance is below the minimum a swap can be made for.
///
/// Carries the limit in sats because the message states it. The *unit* it is
/// rendered in is the user's current display preference, so that choice stays
/// in presentation — `BitcoinUnit` lives in a Flutter-importing file and must
/// not reach this layer.
final class AutoswapBalanceThresholdTooLowFailure extends AutoswapFailure {
  final int minimumSats;

  const AutoswapBalanceThresholdTooLowFailure(this.minimumSats);
}

/// The trigger balance is not at least twice the target balance, so a swap
/// would leave the wallet below its target immediately.
final class AutoswapTriggerBalanceTooLowFailure extends AutoswapFailure {
  const AutoswapTriggerBalanceTooLowFailure();
}

/// The accepted fee ceiling is above what we allow to be set.
final class AutoswapFeeThresholdTooHighFailure extends AutoswapFailure {
  final int maximumPercent;

  const AutoswapFeeThresholdTooHighFailure(this.maximumPercent);
}

/// The Boltz fallback server URL is not a valid absolute HTTPS URL.
final class AutoswapInvalidBoltzServerUrlFailure extends AutoswapFailure {
  const AutoswapInvalidBoltzServerUrlFailure();
}

/// Autoswap is disabled or the user has not acknowledged the warning yet.
final class AutoswapDisabledFailure extends AutoswapFailure {
  const AutoswapDisabledFailure([super.logMessage]);
}

/// The persisted settings break a validation rule.
final class AutoswapInvalidSettingsFailure extends AutoswapFailure {
  final AutoSwapSettingsViolation violation;

  const AutoswapInvalidSettingsFailure(this.violation, [super.logMessage]);
}

/// No default Bitcoin or Liquid wallet exists.
final class AutoswapNoDefaultWalletFailure extends AutoswapFailure {
  const AutoswapNoDefaultWalletFailure([super.logMessage]);
}

/// The Liquid balance is below the trigger threshold.
final class AutoswapInsufficientBalanceFailure extends AutoswapFailure {
  final int currentBalanceSats;
  final int requiredThresholdSats;

  const AutoswapInsufficientBalanceFailure({
    required this.currentBalanceSats,
    required this.requiredThresholdSats,
    String? logMessage,
  }) : super(logMessage);
}

/// The swap execution itself failed (build, sign, broadcast, or provider call).
final class AutoswapExecutionFailure extends AutoswapFailure {
  const AutoswapExecutionFailure([super.logMessage]);
}

/// A Boltz fallback was requested but no Boltz server URL is configured.
final class AutoswapBoltzServerRequiredFailure extends AutoswapFailure {
  const AutoswapBoltzServerRequiredFailure([super.logMessage]);
}

/// The absolute fee exceeds the user's configured percentage threshold.
final class AutoswapFeeLimitExceededFailure extends AutoswapFailure {
  final double feePercent;
  final double thresholdPercent;

  const AutoswapFeeLimitExceededFailure({
    required this.feePercent,
    required this.thresholdPercent,
    String? logMessage,
  }) : super(logMessage);
}

/// The server-provided payin address failed client-side validation.
final class AutoswapInvalidPayinAddressFailure extends AutoswapFailure {
  const AutoswapInvalidPayinAddressFailure([super.logMessage]);
}
