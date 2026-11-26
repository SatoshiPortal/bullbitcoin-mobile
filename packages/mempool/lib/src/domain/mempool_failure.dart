import 'package:primitives/primitives.dart' show Failure, Network;

/// Closed set of every failure the Mempool core layer surfaces across its
/// boundary (the repositories and the server validator). Foreign errors —
/// Drift/storage, HTTP (Dio) — are caught at the boundary, logged
/// raw, and mapped to one of these variants; the raw reason stays in
/// [Failure.logMessage] (logs only).
///
/// Pure Dart, no Flutter and no SDK types. A consuming feature lifts these into
/// its own `<Feature>Failure` for translation — core never reaches the UI
/// untranslated.
sealed class MempoolFailure extends Failure {
  const MempoolFailure([super.logMessage]);
}

enum MempoolServerKind { custom, defaultServer }

/// Could not load a server from storage.
final class MempoolLoadFailure extends MempoolFailure {
  final MempoolServerKind serverKind;

  const MempoolLoadFailure(this.serverKind, [super.logMessage]);
}

final class MempoolUnsupportedNetworkFailure extends MempoolFailure {
  final Network network;

  const MempoolUnsupportedNetworkFailure(this.network);
}

/// Persisting a server or settings failed.
final class MempoolSaveFailure extends MempoolFailure {
  const MempoolSaveFailure([super.logMessage]);
}

/// Deleting the custom server failed.
final class MempoolDeleteFailure extends MempoolFailure {
  const MempoolDeleteFailure([super.logMessage]);
}

/// The custom server URL is malformed (empty, has a path, invalid domain, …).
final class MempoolInvalidUrlFailure extends MempoolFailure {
  const MempoolInvalidUrlFailure([super.logMessage]);
}

/// The custom server URL is identical to the default server.
final class MempoolServerSameAsDefaultFailure extends MempoolFailure {
  const MempoolServerSameAsDefaultFailure([super.logMessage]);
}

// ── Validation failures ──────────────────────────────────────────────────────
// Each variant is the specific, sanitized reason a server failed validation.
// The consuming feature lifts these 1:1 into its own sealed family for
// translation — no secondary enum needed.

final class MempoolValidationTimeoutFailure extends MempoolFailure {
  const MempoolValidationTimeoutFailure([super.logMessage]);
}

final class MempoolValidationHostNotFoundFailure extends MempoolFailure {
  const MempoolValidationHostNotFoundFailure([super.logMessage]);
}

final class MempoolValidationTorNotRunningFailure extends MempoolFailure {
  const MempoolValidationTorNotRunningFailure([super.logMessage]);
}

final class MempoolValidationConnectionErrorFailure extends MempoolFailure {
  const MempoolValidationConnectionErrorFailure([super.logMessage]);
}

final class MempoolValidationNotMempoolServerFailure extends MempoolFailure {
  const MempoolValidationNotMempoolServerFailure([super.logMessage]);
}

final class MempoolValidationServerUnavailableFailure extends MempoolFailure {
  const MempoolValidationServerUnavailableFailure([super.logMessage]);
}

final class MempoolValidationServerErrorFailure extends MempoolFailure {
  const MempoolValidationServerErrorFailure([super.logMessage]);
}

final class MempoolValidationInvalidResponseFailure extends MempoolFailure {
  const MempoolValidationInvalidResponseFailure([super.logMessage]);
}

final class MempoolValidationNetworkMismatchFailure extends MempoolFailure {
  const MempoolValidationNetworkMismatchFailure([super.logMessage]);
}

// ────────────────────────────────────────────────────────────────────────────

/// Anything not otherwise modeled.
final class MempoolUnexpectedFailure extends MempoolFailure {
  const MempoolUnexpectedFailure([super.logMessage]);
}

/// The encrypted store could not be admitted. Deferred failures can be retried.
final class MempoolStorageUnavailableFailure extends MempoolFailure {
  final bool deferred;
  const MempoolStorageUnavailableFailure({required this.deferred});
}
