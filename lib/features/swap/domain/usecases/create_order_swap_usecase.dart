import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_network.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_record.dart';
import 'package:bb_mobile/features/swap/domain/repositories/order_swap_repository.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';

class CreateOrderSwapUsecase {
  final OrderSwapRepository _repository;

  const CreateOrderSwapUsecase(this._repository);

  Future<Result<OrderSwapRecord, SwapFailure>> execute({
    required BigInt amountSat,
    required bool isInAmountFixed,
    required OrderSwapNetwork inNetwork,
    required OrderSwapNetwork outNetwork,
    required String destinationAddress,
    required String? fallbackAddress,
    required OrderSwapPurpose purpose,
    required OrderSwapEnvironment environment,
    String? sourceWalletId,
    String? destinationWalletId,
    String? note,
    BigInt? quotedCounterpartAmountSat,
  }) => _repository.createOrder(
    amountSat: amountSat,
    isInAmountFixed: isInAmountFixed,
    inNetwork: inNetwork,
    outNetwork: outNetwork,
    destinationAddress: destinationAddress,
    fallbackAddress: fallbackAddress,
    purpose: purpose,
    environment: environment,
    sourceWalletId: sourceWalletId,
    destinationWalletId: destinationWalletId,
    note: note,
    quotedCounterpartAmountSat: quotedCounterpartAmountSat,
  );
}
