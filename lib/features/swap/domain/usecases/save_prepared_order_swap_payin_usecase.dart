import 'package:primitives/primitives.dart';
import 'package:swaps/order_swaps.dart';
import 'package:bb_mobile/features/swap/domain/repositories/order_swap_repository.dart';

class SavePreparedOrderSwapPayinUsecase {
  final OrderSwapRepository _repository;

  const SavePreparedOrderSwapPayinUsecase(this._repository);

  Future<Result<OrderSwapRecord, SwapFailure>> execute({
    required String localId,
    required String signedTransaction,
    required bool isPsbt,
  }) => _repository.savePreparedPayin(
    localId: localId,
    signedTransaction: signedTransaction,
    isPsbt: isPsbt,
  );
}
