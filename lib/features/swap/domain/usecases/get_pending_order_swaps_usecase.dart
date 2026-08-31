import 'package:bull_swap/bull_swap.dart';
import 'package:bb_mobile/core/utils/result.dart';

class GetPendingOrderSwapsUsecase {
  final OrderSwapRepository _repository;

  const GetPendingOrderSwapsUsecase(this._repository);

  Future<Result<List<OrderSwapRecord>, SwapFailure>> execute() =>
      _repository.getPendingOrders();
}
