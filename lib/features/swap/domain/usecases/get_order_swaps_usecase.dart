import 'package:primitives/primitives.dart';
import 'package:swaps/order_swaps.dart';
import 'package:bb_mobile/features/swap/domain/repositories/order_swap_repository.dart';

class GetOrderSwapsUsecase {
  final OrderSwapRepository _repository;

  const GetOrderSwapsUsecase(this._repository);

  Future<Result<List<OrderSwapRecord>, SwapFailure>> execute({
    String? walletId,
  }) => _repository.getOrders(walletId: walletId);
}
