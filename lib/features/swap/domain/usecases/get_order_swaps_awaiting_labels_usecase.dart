import 'package:primitives/primitives.dart';
import 'package:swaps/order_swaps.dart';
import 'package:bb_mobile/features/swap/domain/repositories/order_swap_repository.dart';

class GetOrderSwapsAwaitingLabelsUsecase {
  final OrderSwapRepository _repository;

  const GetOrderSwapsAwaitingLabelsUsecase(this._repository);

  Future<Result<List<OrderSwapRecord>, SwapFailure>> execute({
    required OrderSwapPurpose purpose,
  }) => _repository.getOrdersAwaitingLabels(purpose: purpose);
}
