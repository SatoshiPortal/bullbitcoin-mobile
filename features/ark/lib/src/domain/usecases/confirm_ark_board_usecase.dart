import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_board_funding_port.dart';
import '../repositories/ark_preferences_repository.dart';

final class ConfirmArkBoardUsecase {
  final ArkBoardFundingPort _funding;
  final ArkPreferencesRepository _preferences;
  final DateTime Function() _now;
  ConfirmArkBoardUsecase(
    this._funding,
    this._preferences, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  Future<Result<ArkOperation, ArkFailure>> execute(
    ArkAccountId account,
    ArkBoardPreparation reviewed,
  ) async {
    if (reviewed.account != account ||
        reviewed.operationId.trim().isEmpty ||
        reviewed.reviewBinding.trim().isEmpty) {
      return const Err(ArkInvalidRequestFailure());
    }
    if (!_now().isBefore(reviewed.validUntil)) {
      return const Err(ArkReviewExpiredFailure());
    }
    if (!NetworkCapabilities.supports(account.network, NetworkCapability.ark)) {
      return const Err(ArkNetworkUnavailableFailure());
    }
    switch (await _preferences.isEnabled(account)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: false):
        return const Err(ArkDisabledFailure());
      case Ok():
        break;
    }
    final result = await _funding.confirm(
      account,
      reviewed.operationId,
      reviewed.reviewBinding,
    );
    if (result case Ok(:final value)) {
      if (value.id != reviewed.operationId ||
          value.kind != ArkOperationKind.board) {
        return Err(ArkSubmissionUncertainFailure(reviewed.operationId));
      }
    }
    // Every post-dispatch Err can follow an admitted effect. Keep the same ID.
    return result.mapErr(
      (_) => ArkSubmissionUncertainFailure(reviewed.operationId),
    );
  }
}
