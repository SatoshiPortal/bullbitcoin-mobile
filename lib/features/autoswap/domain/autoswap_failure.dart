import 'package:bb_mobile/core/failures/failure.dart';

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

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI — the
/// presentation extension returns the shared generic string.
final class AutoswapUnexpectedFailure extends AutoswapFailure {
  const AutoswapUnexpectedFailure([super.logMessage]);
}
