import 'package:bull_swap/bull_swap.dart';
import 'package:bb_mobile/core/utils/result.dart';

class MarkOrderSwapPayinBroadcastUsecase {
  final OrderSwapRepository _repository;

  const MarkOrderSwapPayinBroadcastUsecase(this._repository);

  Future<Result<OrderSwapRecord, SwapFailure>> execute({
    required String localId,
    required String transactionId,
  }) => _repository.markPayinBroadcast(
    localId: localId,
    transactionId: transactionId,
  );
}
