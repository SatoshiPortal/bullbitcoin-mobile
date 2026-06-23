import 'package:bb_mobile/core/failures/failure.dart';

/// Closed set of every failure the Electrum core layer surfaces across its
/// boundary (the repositories). Foreign errors — Drift/storage, connectivity,
/// domain-entity validation — are caught at the boundary, logged raw, and
/// mapped to one of these variants; the raw reason stays in
/// [Failure.logMessage] (logs only).
///
/// Pure Dart, no Flutter and no SDK types. A consuming feature lifts these into
/// its own `<Feature>Failure` for translation — core never reaches the UI
/// untranslated.
sealed class ElectrumFailure extends Failure {
  const ElectrumFailure([super.logMessage]);
}

/// Could not load the servers/settings from storage.
final class ElectrumLoadFailure extends ElectrumFailure {
  const ElectrumLoadFailure([super.logMessage]);
}

/// Persisting a server or settings failed (save / batchSave).
final class ElectrumSaveFailure extends ElectrumFailure {
  const ElectrumSaveFailure([super.logMessage]);
}

/// Deleting a server failed.
final class ElectrumDeleteFailure extends ElectrumFailure {
  const ElectrumDeleteFailure([super.logMessage]);
}

/// A server with the same url already exists.
final class ElectrumServerAlreadyExistsFailure extends ElectrumFailure {
  const ElectrumServerAlreadyExistsFailure([super.logMessage]);
}

/// The server's socket / protocol checks failed — it is unreachable.
final class ElectrumServerUnreachableFailure extends ElectrumFailure {
  const ElectrumServerUnreachableFailure([super.logMessage]);
}

/// stopGap is out of range. [value] is the offending value (sanitized).
final class ElectrumInvalidStopGapFailure extends ElectrumFailure {
  final int value;

  const ElectrumInvalidStopGapFailure(this.value, [super.logMessage]);
}

/// timeout is out of range. [value] is the offending value (sanitized).
final class ElectrumInvalidTimeoutFailure extends ElectrumFailure {
  final int value;

  const ElectrumInvalidTimeoutFailure(this.value, [super.logMessage]);
}

/// retry is out of range. [value] is the offending value (sanitized).
final class ElectrumInvalidRetryFailure extends ElectrumFailure {
  final int value;

  const ElectrumInvalidRetryFailure(this.value, [super.logMessage]);
}

/// Anything not otherwise modeled.
final class ElectrumUnexpectedFailure extends ElectrumFailure {
  const ElectrumUnexpectedFailure([super.logMessage]);
}
