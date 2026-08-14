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

final class NetworkMismatchFailure extends ImportWatchOnlyFailure {
  const NetworkMismatchFailure();
}
