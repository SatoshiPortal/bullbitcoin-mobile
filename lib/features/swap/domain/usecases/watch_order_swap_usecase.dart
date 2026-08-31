import 'package:bull_swap/bull_swap.dart';
import 'package:bb_mobile/core/utils/result.dart';

class WatchOrderSwapUsecase {
  final OrderSwapRepository _repository;

  const WatchOrderSwapUsecase(this._repository);

  Stream<Result<OrderSwapRecord, SwapFailure>> execute(String localId) =>
      _repository.watchOrder(localId);
}
