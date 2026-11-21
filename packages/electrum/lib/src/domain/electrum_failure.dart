import 'electrum_server_network.dart';

import 'package:primitives/primitives.dart' show Failure;

/// Closed set of failures the Electrum owner surfaces across its
/// boundary (the repositories). Foreign errors — Drift/storage, connectivity,
/// domain-entity validation — are caught at the boundary, logged by safe category, and
/// mapped to one of these variants; optional safe diagnostics stay in
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

/// The configured external Tor proxy is unavailable, so a clearnet server
/// cannot be probed without violating the fail-closed routing policy.
final class ElectrumExternalTorProxyUnavailableFailure extends ElectrumFailure {
  const ElectrumExternalTorProxyUnavailableFailure([super.logMessage]);
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

/// The SDK cannot serve this concrete network.
final class ElectrumUnsupportedNetworkFailure extends ElectrumFailure {
  const ElectrumUnsupportedNetworkFailure();
}

/// Foreground initialization has not completed, or headless data is incomplete.
final class ElectrumStorageNotReadyFailure extends ElectrumFailure {
  const ElectrumStorageNotReadyFailure();
}

/// Closed set of failures shown in the server-list section of the Electrum
/// settings screen. Lifted from the core [ElectrumFailure] by the bloc and
/// rendered via the presentation `toTranslated` extension — the raw reason
/// stays in [Failure.logMessage] (logs only) and never reaches the UI.
sealed class ElectrumServersFailure extends ElectrumFailure {
  const ElectrumServersFailure([super.logMessage]);
}

final class ElectrumServersLoadFailure extends ElectrumServersFailure {
  const ElectrumServersLoadFailure([super.logMessage]);
}

final class ElectrumServersSavePriorityFailure extends ElectrumServersFailure {
  const ElectrumServersSavePriorityFailure([super.logMessage]);
}

final class ElectrumServersAddFailure extends ElectrumServersFailure {
  const ElectrumServersAddFailure([super.logMessage]);
}

final class ElectrumServersDeleteFailure extends ElectrumServersFailure {
  const ElectrumServersDeleteFailure([super.logMessage]);
}

final class ElectrumServersAlreadyExistsFailure extends ElectrumServersFailure {
  const ElectrumServersAlreadyExistsFailure([super.logMessage]);
}

final class ElectrumServersUnreachableFailure extends ElectrumServersFailure {
  const ElectrumServersUnreachableFailure([super.logMessage]);
}

final class ElectrumServersExternalTorProxyUnavailableFailure
    extends ElectrumServersFailure {
  const ElectrumServersExternalTorProxyUnavailableFailure([super.logMessage]);
}

final class ElectrumServersUnexpectedFailure extends ElectrumServersFailure {
  const ElectrumServersUnexpectedFailure([super.logMessage]);
}

/// Closed set of failures shown in the advanced-options sheet. The `Invalid*`
/// variants carry the offending [value] (sanitized user input) for its
/// message; the rest carry only [Failure.logMessage].
sealed class AdvancedOptionsFailure extends ElectrumFailure {
  const AdvancedOptionsFailure([super.logMessage]);
}

final class AdvancedOptionsInvalidStopGapFailure
    extends AdvancedOptionsFailure {
  final String value;

  const AdvancedOptionsInvalidStopGapFailure(this.value, [super.logMessage]);
}

final class AdvancedOptionsInvalidTimeoutFailure
    extends AdvancedOptionsFailure {
  final String value;

  const AdvancedOptionsInvalidTimeoutFailure(this.value, [super.logMessage]);
}

final class AdvancedOptionsInvalidRetryFailure extends AdvancedOptionsFailure {
  final String value;

  const AdvancedOptionsInvalidRetryFailure(this.value, [super.logMessage]);
}

final class AdvancedOptionsSaveFailure extends AdvancedOptionsFailure {
  const AdvancedOptionsSaveFailure([super.logMessage]);
}

final class AdvancedOptionsUnexpectedFailure extends AdvancedOptionsFailure {
  const AdvancedOptionsUnexpectedFailure([super.logMessage]);
}

/// The active network has no configured transaction server.
final class ElectrumNoTransactionServersFailure extends ElectrumFailure {
  final ElectrumServerNetwork network;

  const ElectrumNoTransactionServersFailure(this.network);
}

/// The transaction lookup exhausted the active server set.
final class ElectrumTransactionFetchFailure extends ElectrumFailure {
  final String txid;

  const ElectrumTransactionFetchFailure(this.txid);
}
