import 'package:bb_mobile/features/swap/domain/repositories/order_swap_repository.dart';

class WatchSwapAppUpdateRequiredUsecase {
  final OrderSwapRepository _repository;

  WatchSwapAppUpdateRequiredUsecase(this._repository);

  Stream<bool> execute() => _repository.watchAppUpdateRequired();
}
