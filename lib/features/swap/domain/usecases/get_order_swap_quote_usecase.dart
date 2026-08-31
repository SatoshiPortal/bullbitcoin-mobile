import 'package:bull_swap/bull_swap.dart';
import 'package:bb_mobile/core/utils/result.dart';

class GetOrderSwapQuoteUsecase {
  final OrderSwapRepository _repository;

  const GetOrderSwapQuoteUsecase(this._repository);

  Future<Result<OrderSwapQuote, SwapFailure>> execute({
    required OrderSwapEnvironment environment,
    required BigInt amountSat,
    required bool isInAmountFixed,
    required OrderSwapNetwork inNetwork,
    required OrderSwapNetwork outNetwork,
  }) => _repository.getQuote(
    environment: environment,
    amountSat: amountSat,
    isInAmountFixed: isInAmountFixed,
    inNetwork: inNetwork,
    outNetwork: outNetwork,
  );
}
