import 'package:bull_swap/bull_swap.dart';
import 'package:bb_mobile/core/utils/result.dart';

class MarkOrderSwapBroadcastUnknownUsecase {
  final OrderSwapRepository _repository;

  const MarkOrderSwapBroadcastUnknownUsecase(this._repository);

  Future<Result<OrderSwapRecord, SwapFailure>> execute(String localId) =>
      _repository.markBroadcastUnknown(localId);
}
