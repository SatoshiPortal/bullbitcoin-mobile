import 'package:bb_mobile/core/failures/failure.dart';

sealed class ConsolidationFailure extends Failure {
  const ConsolidationFailure([super.logMessage]);
}

/// A Liquid send/swap build was blocked because the wallet holds more
/// confirmed L-BTC UTXOs than a single confidential transaction can spend.
/// Consolidate before retrying.
final class ConsolidationRequiredFailure extends ConsolidationFailure {
  const ConsolidationRequiredFailure([super.logMessage]);
}

/// The wallet's L-BTC UTXO count could not be read.
final class ConsolidationCountUnavailableFailure extends ConsolidationFailure {
  const ConsolidationCountUnavailableFailure([super.logMessage]);
}

/// Building the unsigned consolidation PSET(s) failed.
final class ConsolidationBuildFailure extends ConsolidationFailure {
  const ConsolidationBuildFailure([super.logMessage]);
}

/// Signing one of the consolidation PSETs failed. [succeededTxids] holds the
/// txids of any earlier batches that already broadcast successfully before
/// this one failed to sign — a retry must not resend those.
final class ConsolidationSignFailure extends ConsolidationFailure {
  const ConsolidationSignFailure(this.succeededTxids, [super.logMessage]);

  final List<String> succeededTxids;
}

/// Broadcasting one of the consolidation transactions failed, after it was
/// signed. [succeededTxids] holds the txids of any earlier batches that
/// already broadcast successfully before this one failed — a retry must not
/// resend those.
final class ConsolidationBroadcastFailure extends ConsolidationFailure {
  const ConsolidationBroadcastFailure(this.succeededTxids, [super.logMessage]);

  final List<String> succeededTxids;
}

/// Anything not otherwise modeled.
final class ConsolidationUnexpectedFailure extends ConsolidationFailure {
  const ConsolidationUnexpectedFailure([super.logMessage]);
}

/// Refreshing the wallet's local UTXO view failed while retrying after a
/// previous failure — surfaced instead of silently attempting to rebuild
/// against a possibly-stale view (which could re-offer an outpoint an
/// earlier, partially-successful broadcast round already spent; the build
/// itself would succeed, since it has no way to know that, and only fail
/// later, confusingly, when signing/broadcasting rejects it as a
/// double-spend). No batch was built or broadcast this round.
final class ConsolidationSyncFailure extends ConsolidationFailure {
  const ConsolidationSyncFailure([super.logMessage]);
}
