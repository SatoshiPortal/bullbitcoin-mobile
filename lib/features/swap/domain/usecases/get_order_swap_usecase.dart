import 'package:bull_swap/bull_swap.dart';
import 'package:bb_mobile/core/utils/result.dart';

class GetOrderSwapUsecase {
  final OrderSwapRepository _repository;

  const GetOrderSwapUsecase(this._repository);

  Future<Result<OrderSwapRecord, SwapFailure>> execute(String localId) =>
      _repository.getOrder(localId);
}
