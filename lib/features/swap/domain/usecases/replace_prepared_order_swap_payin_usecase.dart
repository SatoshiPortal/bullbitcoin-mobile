import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_record.dart';
import 'package:bb_mobile/features/swap/domain/repositories/order_swap_repository.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';

class ReplacePreparedOrderSwapPayinUsecase {
  final OrderSwapRepository _repository;

  const ReplacePreparedOrderSwapPayinUsecase(this._repository);

  Future<Result<OrderSwapRecord, SwapFailure>> execute({
    required String localId,
    required String signedTransaction,
    required bool isPsbt,
  }) => _repository.replacePreparedPayin(
    localId: localId,
    signedTransaction: signedTransaction,
    isPsbt: isPsbt,
  );
}
