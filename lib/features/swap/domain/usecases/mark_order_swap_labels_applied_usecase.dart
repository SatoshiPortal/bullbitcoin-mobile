import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_record.dart';
import 'package:bb_mobile/features/swap/domain/repositories/order_swap_repository.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';

class MarkOrderSwapLabelsAppliedUsecase {
  final OrderSwapRepository _repository;

  const MarkOrderSwapLabelsAppliedUsecase(this._repository);

  Future<Result<OrderSwapRecord, SwapFailure>> execute({
    required String localId,
    required DateTime appliedAt,
  }) => _repository.markLabelsApplied(localId: localId, appliedAt: appliedAt);
}
