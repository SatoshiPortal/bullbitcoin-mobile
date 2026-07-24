import 'package:bb_mobile/core/failures/failure.dart';

/// Closed set of every failure the watch-only import flow surfaces to the user.
/// `sealed` keeps it closed (exhaustive switches; no foreign variants). Pure
/// Dart — the user-facing message lives in the presentation extension
/// `import_watch_only_failure_l10n.dart`, never here.
sealed class ImportWatchOnlyFailure extends Failure {
  const ImportWatchOnlyFailure([super.logMessage]);
}

final class NoWalletSelectedFailure extends ImportWatchOnlyFailure {
  const NoWalletSelectedFailure();
}

final class LabelRequiredFailure extends ImportWatchOnlyFailure {
  const LabelRequiredFailure();
}

final class InvalidFormatFailure extends ImportWatchOnlyFailure {
  const InvalidFormatFailure();
}

final class ImportFailedFailure extends ImportWatchOnlyFailure {
  const ImportFailedFailure();
}

/// The requested compact-block-filter wallet birthday could not be resolved
/// to a concrete checkpoint (see `WalletBirthdayCheckpointFailure`, lifted
/// from that core failure family at the descriptor/xpub usecases'
/// boundary — the raw core type never reaches this feature's presentation
/// layer). The user can retry the same birthday or fall back to the
/// earliest possible one (genesis), which never requires a network lookup.
/// [logMessage] is for logs/Sentry ONLY and MUST never reach the UI.
final class BirthdayCheckpointFailure extends ImportWatchOnlyFailure {
  const BirthdayCheckpointFailure([super.logMessage]);
}
