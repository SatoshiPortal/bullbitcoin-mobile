import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_record.dart';
import 'package:bb_mobile/features/swap/domain/repositories/order_swap_repository.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';

class WatchOrderSwapUsecase {
  final OrderSwapRepository _repository;

  const WatchOrderSwapUsecase(this._repository);

  Stream<Result<OrderSwapRecord, SwapFailure>> execute(String localId) =>
      _repository.watchOrder(localId);
}
