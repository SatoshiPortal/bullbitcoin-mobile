import 'package:silent/silent.dart';

/// Wallet feature's own use case wrapping the Silent Payments facade, so the
/// `WalletBloc` never calls `Silent` directly (AGENTS.md rule #4).
///
/// Whether an SP scan is running; the bloc skips the refresh while true so it
/// never disposes the live session mid-scan.
class CheckSpScanningForWalletUsecase {
  final Silent _silent;

  CheckSpScanningForWalletUsecase({required this._silent});

  bool execute() => _silent.isScanning;
}
