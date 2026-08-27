import 'package:bb_mobile/core/wallet/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Whether [ConsolidationBanner] should show for one wallet — the seam
/// between that widget and [CheckLiquidConsolidationUsecase], so the widget
/// never resolves/calls the use-case itself (ui → presentation → usecase,
/// AGENTS.md rule #2). One instance per banner (per wallet), created via
/// `locator<ConsolidationBannerCubit>(param1: walletId)`.
class ConsolidationBannerCubit extends Cubit<bool> {
  final CheckLiquidConsolidationUsecase _check;

  final String _walletId;

  ConsolidationBannerCubit({
    required CheckLiquidConsolidationUsecase checkLiquidConsolidationUsecase,
    required this._walletId,
  }) : _check = checkLiquidConsolidationUsecase,
       super(false);

  /// Best-effort: this drives a non-critical banner, so a failed read just
  /// keeps the last known value rather than surfacing an error.
  Future<void> reload() async {
    try {
      final required = await _check.execute(walletId: _walletId);
      if (!isClosed) emit(required);
    } catch (_) {
      // Keep the last known value.
    }
  }
}
