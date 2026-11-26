import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/entities/sp_balance.dart';

/// Immutable snapshot of the Silent Payments wallet.
///
/// This is a pure domain value object; it holds the data other layers care
/// about (addresses, balance, scan state) and deliberately does NOT hold the
/// live Rust FFI session. The live session is owned by the
/// `SpAccountRepository` adapter; presentation/state hold only this snapshot.
class SilentWallet {
  /// Proven by session admission; null snapshots cannot contribute to home.
  final BitcoinNetwork? network;

  /// The reusable Silent Payments address (BIP-352). Safe to display
  /// persistently and to reuse across payers.
  final String spAddress;
  final SilentBalance balance;
  final bool isScanning;

  /// True when a manual scan left a resume marker on disk, so a restart can
  /// pick the scan up instead of waiting for the user.
  final bool hasPendingScan;

  /// True when the pending scan was stopped by the user: it is reported, not
  /// resumed automatically.
  final bool isPendingScanPaused;
  final int? lastScannedHeight;

  const SilentWallet({
    this.network,
    required this.spAddress,
    required this.balance,
    required this.isScanning,
    this.hasPendingScan = false,
    this.isPendingScanPaused = false,
    this.lastScannedHeight,
  });
}
