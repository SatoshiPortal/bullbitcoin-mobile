import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';

/// Immutable snapshot of the Silent Payments wallet.
///
/// This is a pure domain value object; it holds the data other layers care
/// about (addresses, balance, scan state) and deliberately does NOT hold the
/// live Rust FFI session. The live session is owned by the
/// `SpAccountRepository` adapter; presentation/state hold only this snapshot.
class SpWallet {
  /// The reusable Silent Payments address (BIP-352). Safe to display
  /// persistently and to reuse across payers.
  final String spAddress;
  final SpBalance balance;
  final bool isScanning;
  final int? lastScannedHeight;

  const SpWallet({
    required this.spAddress,
    required this.balance,
    required this.isScanning,
    this.lastScannedHeight,
  });

  BigInt get confirmedSat => balance.confirmedSat;
}
