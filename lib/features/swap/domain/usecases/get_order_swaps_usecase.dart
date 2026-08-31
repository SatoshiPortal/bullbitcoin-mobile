import 'package:bull_swap/bull_swap.dart';
import 'package:bb_mobile/core/utils/result.dart';

class GetOrderSwapsUsecase {
  final OrderSwapRepository _repository;

  const GetOrderSwapsUsecase(this._repository);

  Future<Result<List<OrderSwapRecord>, SwapFailure>> execute({
    String? walletId,
  }) => _repository.getOrders(walletId: walletId);
}
