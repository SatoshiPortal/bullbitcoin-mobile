import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_board_funding_port.dart';

/// Reads the host journal; no caller-supplied display object becomes a review.
final class ReadArkBoardUsecase {
  final ArkBoardFundingPort _funding;
  const ReadArkBoardUsecase(this._funding);

  Future<Result<ArkBoardPreparation, ArkFailure>> execute(
    ArkAccountId account,
    String operationId,
  ) async {
    if (operationId.trim().isEmpty) {
      return const Err(ArkInvalidRequestFailure());
    }
    final result = await _funding.readPrepared(account, operationId);
    if (result case Ok(:final value)) {
      if (value.account != account ||
          value.operationId != operationId ||
          value.reviewBinding.trim().isEmpty) {
        return const Err(ArkInvalidRequestFailure());
      }
    }
    return result;
  }
}
