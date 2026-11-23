import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:silent/src/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:silent/src/domain/entities/sp_wallet.dart';

/// Loads the SP wallet snapshot, enforcing the superuser + dev-mode gate.
///
/// The gate lives here (not in the adapter) so the secondary adapter stays
/// free of use-case/settings concerns. `EnsureSpSessionUsecase` establishes
/// the live session (reconstructing it from the persisted config) and returns
/// null when the wallet is not set up (revoked / no config / no secret).
class GetSpWalletUsecase {
  final EnsureSpSessionUsecase _ensureSpSessionUsecase;
  final GetSpFeatureGateUsecase _getSpFeatureGateUsecase;

  GetSpWalletUsecase({
    required this._ensureSpSessionUsecase,
    required this._getSpFeatureGateUsecase,
  });

  /// `Ok(null)` when the gate is closed or the wallet is not set up.
  Future<Result<SilentWallet?, SilentFailure>> execute() async {
    return switch (await _getSpFeatureGateUsecase.check()) {
      Err(:final failure) => Err(failure),
      Ok(value: false) => const Ok(null),
      Ok(value: true) => await _ensureSpSessionUsecase.execute(),
    };
  }
}
