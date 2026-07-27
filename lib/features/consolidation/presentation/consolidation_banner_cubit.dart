import 'package:bb_mobile/features/consolidation/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConsolidationBannerCubit extends Cubit<bool> {
  final CheckLiquidConsolidationUsecase _check;

  final String _walletId;

  ConsolidationBannerCubit({
    required CheckLiquidConsolidationUsecase checkLiquidConsolidationUsecase,
    required this._walletId,
  }) : _check = checkLiquidConsolidationUsecase,
       super(false);

  Future<void> reload() async {
    try {
      final status = await _check.execute(walletId: _walletId);
      if (!isClosed) emit(status.isRequired);
    } catch (_) {
      // Keep the last known value.
    }
  }
}
