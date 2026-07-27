export 'package:bb_mobile/features/consolidation/domain/consolidation_failure.dart';
export 'package:bb_mobile/features/consolidation/presentation/consolidation_failure_l10n.dart';
export 'package:bb_mobile/features/consolidation/ui/consolidation_router.dart';
export 'package:bb_mobile/features/consolidation/ui/widgets/consolidation_banner.dart';

import 'package:bb_mobile/features/consolidation/domain/usecases/check_liquid_consolidation_usecase.dart';

class ConsolidationFacade {
  final CheckLiquidConsolidationUsecase _check;

  ConsolidationFacade({
    required CheckLiquidConsolidationUsecase checkLiquidConsolidationUsecase,
  }) : _check = checkLiquidConsolidationUsecase;

  Future<bool> isConsolidationRequired({required String walletId}) async {
    final status = await _check.execute(walletId: walletId);
    return status.isRequired;
  }
}
