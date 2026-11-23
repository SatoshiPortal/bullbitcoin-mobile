import 'package:primitives/primitives.dart';
import 'package:swaps/order_swaps.dart';
import 'package:bb_mobile/features/swap/domain/repositories/order_swap_repository.dart';

class RefreshOrderSwapUsecase {
  final OrderSwapRepository _repository;

  const RefreshOrderSwapUsecase(this._repository);

  Future<Result<OrderSwapRecord, SwapFailure>> execute(String localId) =>
      _repository.refreshOrder(localId);
}
