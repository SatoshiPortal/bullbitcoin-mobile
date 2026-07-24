import 'package:bb_mobile/core/failures/failure.dart';

/// Closed set of every failure `ResolveWalletBirthdayCheckpointUsecase`
/// surfaces across its boundary when resolving a wallet's requested
/// birthday (see `WalletBirthdayCheckpoint`, `domain/entities/`) to a
/// concrete block.
///
/// Pure Dart, no Flutter and no SDK types. This is a core-layer failure, so
/// a consuming feature lifts it into its own `<Feature>Failure` for
/// translation — core never reaches the UI untranslated.
sealed class WalletBirthdayCheckpointFailure extends Failure {
  const WalletBirthdayCheckpointFailure([super.logMessage]);
}

/// The lookup itself failed this time — the active mempool server could not
/// be resolved, the HTTP call to it failed, its response was malformed, or
/// it kept answering with a block later than the requested lookup date past
/// `WalletBirthdayCheckpointRepositoryImpl`'s bounded retry budget.
/// [Failure.logMessage] carries only a non-sensitive classification, never
/// a wallet id, descriptor, or address.
final class WalletBirthdayCheckpointLookupFailure
    extends WalletBirthdayCheckpointFailure {
  const WalletBirthdayCheckpointLookupFailure([super.logMessage]);
}

/// Anything not otherwise modeled.
final class WalletBirthdayCheckpointUnexpectedFailure
    extends WalletBirthdayCheckpointFailure {
  const WalletBirthdayCheckpointUnexpectedFailure([super.logMessage]);
}
