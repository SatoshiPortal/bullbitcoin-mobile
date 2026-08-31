import 'package:bull_swap/bull_swap.dart';
import 'package:bb_mobile/core/utils/result.dart';

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
