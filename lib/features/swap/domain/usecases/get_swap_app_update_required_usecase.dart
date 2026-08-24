import 'package:bb_mobile/features/swap/domain/repositories/order_swap_repository.dart';

class GetSwapAppUpdateRequiredUsecase {
  final OrderSwapRepository _repository;

  GetSwapAppUpdateRequiredUsecase(this._repository);

  bool execute() => _repository.isAppUpdateRequired;
}
