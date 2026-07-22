import 'package:bb_mobile/features/consolidation/public/consolidation_facade.dart';

class CheckLiquidConsolidationRequiredUsecase {
  final ConsolidationFacade _facade;

  CheckLiquidConsolidationRequiredUsecase({
    required ConsolidationFacade consolidationFacade,
  }) : _facade = consolidationFacade;

  Future<bool> execute({required String walletId}) {
    return _facade.isConsolidationRequired(walletId: walletId);
  }
}
