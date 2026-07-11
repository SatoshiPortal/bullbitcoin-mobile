import 'package:bb_mobile/features/sp/public/sp_facade.dart';

/// Wallet feature's own use case wrapping the Silent Payments facade, so the
/// `WalletBloc` never calls `SpFacade` directly (AGENTS.md rule #4).
///
/// Whether an SP scan is running; the bloc skips the refresh while true so it
/// never disposes the live session mid-scan.
class CheckSpScanningForWalletUsecase {
  final SpFacade _spFacade;

  CheckSpScanningForWalletUsecase({required this._spFacade});

  bool execute() => _spFacade.isScanning;
}
