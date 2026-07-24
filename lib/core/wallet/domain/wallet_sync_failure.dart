import 'package:bb_mobile/core/failures/failure.dart';

/// Closed set of every failure a `WalletSyncRepository` surfaces across its
/// boundary. Foreign errors (Electrum fallback exceptions, a missing wallet)
/// are caught at the repository, logged raw, and mapped to one of these
/// variants; the raw reason stays in [Failure.logMessage] (logs only).
///
/// Pure Dart, no Flutter and no SDK types. This is a core-layer failure, so a
/// consuming feature lifts it into its own `<Feature>Failure` for
/// translation — core never reaches the UI untranslated.
sealed class WalletSyncFailure extends Failure {
  const WalletSyncFailure([super.logMessage]);
}

/// No wallet metadata exists for the requested id. Deliberately does not
/// store or log the wallet id — it is a per-wallet contract, so the caller
/// that already has the id does not need it echoed back.
final class WalletSyncWalletNotFoundFailure extends WalletSyncFailure {
  const WalletSyncWalletNotFoundFailure() : super('Wallet not found');
}

/// A sync backend was requested for a wallet that exists but is not a
/// Bitcoin wallet. `BitcoinSyncBackend` (Electrum vs. compact block
/// filters) is a Bitcoin-only concept — Liquid has no CBF equivalent.
final class WalletSyncNotBitcoinWalletFailure extends WalletSyncFailure {
  const WalletSyncNotBitcoinWalletFailure() : super('Not a Bitcoin wallet');
}

/// Every Electrum server failed, or none is configured, for the wallet's
/// network. Mirrors `ElectrumFallbackException` one level up; the
/// per-server attempt detail stays in [Failure.logMessage].
final class WalletSyncElectrumFailure extends WalletSyncFailure {
  const WalletSyncElectrumFailure([super.logMessage]);
}

/// A compact-filter sync was requested for a wallet, but the developer gate
/// is closed: either this is not a debug build, or developer mode is
/// disabled in settings. Carries no detail — the gate itself is the whole
/// story.
final class WalletSyncDeveloperGateClosedFailure extends WalletSyncFailure {
  const WalletSyncDeveloperGateClosedFailure()
    : super('cbf_developer_gate_closed');
}

/// A compact-filter sync was requested while the user has Tor proxy
/// enabled. V1 compact-filter sync does not route through Tor (see
/// `docs/compact-block-filters-*`), so starting it would silently bypass
/// the user's Tor setting — refused instead.
final class WalletSyncTorUnsupportedFailure extends WalletSyncFailure {
  const WalletSyncTorUnsupportedFailure() : super('cbf_tor_unsupported');
}

/// The compact-filter backend failed to build, connect, scan, or apply an
/// update for a wallet. [Failure.logMessage] carries only a non-sensitive
/// classification (e.g. an exception type name) — never a peer, wallet id,
/// descriptor, transaction id, or native warning payload.
final class WalletSyncCbfFailure extends WalletSyncFailure {
  const WalletSyncCbfFailure([super.logMessage]);
}

/// Anything not otherwise modeled.
final class WalletSyncUnexpectedFailure extends WalletSyncFailure {
  const WalletSyncUnexpectedFailure([super.logMessage]);
}
