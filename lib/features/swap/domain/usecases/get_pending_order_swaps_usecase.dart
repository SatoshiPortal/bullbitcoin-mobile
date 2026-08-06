import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_record.dart';
import 'package:bb_mobile/features/swap/domain/repositories/order_swap_repository.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';

class GetPendingOrderSwapsUsecase {
  final OrderSwapRepository _repository;

  const GetPendingOrderSwapsUsecase(this._repository);

  Future<Result<List<OrderSwapRecord>, SwapFailure>> execute() =>
      _repository.getPendingOrders();
}
