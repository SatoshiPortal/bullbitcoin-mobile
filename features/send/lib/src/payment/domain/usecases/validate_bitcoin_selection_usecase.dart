import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';

import '../send_failure.dart';

class ValidateBitcoinSelectionUsecase {
  final Spend _spend;

  const ValidateBitcoinSelectionUsecase(this._spend);

  Future<Result<void, SendFailure>> execute({
    required String walletId,
    Set<Outpoint>? selectedInputs,
  }) async =>
      (await _spend.validateBitcoinSelection(
        walletId: walletId,
        selectedInputs: selectedInputs,
      )).mapErr(
        (failure) => SendSelectedCoinsUnavailableFailure(failure.logMessage),
      );
}
