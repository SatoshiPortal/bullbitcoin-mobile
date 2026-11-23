import 'package:primitives/primitives.dart';
import 'package:swaps/order_swaps.dart';
import 'package:bb_mobile/features/swap/domain/repositories/order_swap_repository.dart';

class GetPendingOrderSwapsUsecase {
  final OrderSwapRepository _repository;

  const GetPendingOrderSwapsUsecase(this._repository);

  Future<Result<List<OrderSwapRecord>, SwapFailure>> execute() =>
      _repository.getPendingOrders();
}
