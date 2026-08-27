import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_record.dart';
import 'package:bb_mobile/features/swap/domain/repositories/order_swap_repository.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';

class GetOrderSwapsUsecase {
  final OrderSwapRepository _repository;

  const GetOrderSwapsUsecase(this._repository);

  Future<Result<List<OrderSwapRecord>, SwapFailure>> execute({
    String? walletId,
  }) => _repository.getOrders(walletId: walletId);
}
