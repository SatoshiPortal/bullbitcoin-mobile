import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';

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

  Future<SpWallet?> execute() async {
    if (!await _getSpFeatureGateUsecase.execute()) return null;

    return _ensureSpSessionUsecase.execute();
  }
}
