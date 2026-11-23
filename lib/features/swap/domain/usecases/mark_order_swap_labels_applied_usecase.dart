import 'package:primitives/primitives.dart';
import 'package:swaps/order_swaps.dart';
import 'package:bb_mobile/features/swap/domain/repositories/order_swap_repository.dart';

class MarkOrderSwapLabelsAppliedUsecase {
  final OrderSwapRepository _repository;

  const MarkOrderSwapLabelsAppliedUsecase(this._repository);

  Future<Result<OrderSwapRecord, SwapFailure>> execute({
    required String localId,
    required DateTime appliedAt,
  }) => _repository.markLabelsApplied(localId: localId, appliedAt: appliedAt);
}
