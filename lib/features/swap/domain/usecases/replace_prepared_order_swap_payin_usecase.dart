import 'package:primitives/primitives.dart';
import 'package:swaps/order_swaps.dart';
import 'package:bb_mobile/features/swap/domain/repositories/order_swap_repository.dart';

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
