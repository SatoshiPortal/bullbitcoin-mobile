import 'package:bull_swap/bull_swap.dart';
import 'package:bb_mobile/core/utils/result.dart';

class RefreshOrderSwapUsecase {
  final OrderSwapRepository _repository;

  const RefreshOrderSwapUsecase(this._repository);

  Future<Result<OrderSwapRecord, SwapFailure>> execute(String localId) =>
      _repository.refreshOrder(localId);
}
