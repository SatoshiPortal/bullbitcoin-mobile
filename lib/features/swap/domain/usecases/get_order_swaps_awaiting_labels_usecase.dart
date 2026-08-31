import 'package:bull_swap/bull_swap.dart';
import 'package:bb_mobile/core/utils/result.dart';

class GetOrderSwapsAwaitingLabelsUsecase {
  final OrderSwapRepository _repository;

  const GetOrderSwapsAwaitingLabelsUsecase(this._repository);

  Future<Result<List<OrderSwapRecord>, SwapFailure>> execute({
    required OrderSwapPurpose purpose,
  }) => _repository.getOrdersAwaitingLabels(purpose: purpose);
}
