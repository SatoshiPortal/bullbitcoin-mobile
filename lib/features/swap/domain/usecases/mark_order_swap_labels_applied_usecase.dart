import 'package:bull_swap/bull_swap.dart';
import 'package:bb_mobile/core/utils/result.dart';

class MarkOrderSwapLabelsAppliedUsecase {
  final OrderSwapRepository _repository;

  const MarkOrderSwapLabelsAppliedUsecase(this._repository);

  Future<Result<OrderSwapRecord, SwapFailure>> execute({
    required String localId,
    required DateTime appliedAt,
  }) => _repository.markLabelsApplied(localId: localId, appliedAt: appliedAt);
}
