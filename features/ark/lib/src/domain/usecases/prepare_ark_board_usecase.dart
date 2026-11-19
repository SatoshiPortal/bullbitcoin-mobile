import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_board_funding_port.dart';
import '../repositories/ark_preferences_repository.dart';

final class PrepareArkBoardUsecase {
  final ArkBoardFundingPort _funding;
  final ArkPreferencesRepository _preferences;
  const PrepareArkBoardUsecase(this._funding, this._preferences);

  Future<Result<ArkBoardPreparation, ArkFailure>> execute(
    ArkAccountConfig config,
    Sats amount, {
    String? expectedSourceWalletId,
  }) async {
    if (amount.value <= BigInt.zero) {
      return const Err(ArkInvalidRequestFailure());
    }
    if (!NetworkCapabilities.supports(
      config.id.network,
      NetworkCapability.ark,
    )) {
      return const Err(ArkNetworkUnavailableFailure());
    }
    switch (await _preferences.isEnabled(config.id)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: false):
        return const Err(ArkDisabledFailure());
      case Ok():
        break;
    }
    final Result<ArkBoardPreparation, ArkFailure> result;
    switch ((expectedSourceWalletId, _funding)) {
      case (null, final funding):
        result = await funding.prepare(config, amount);
      case (final source?, ArkTransferBoardFundingPort funding):
        result = await funding.prepareFrom(
          config,
          amount,
          sourceWalletId: source,
        );
      default:
        return const Err(ArkServiceUnavailableFailure());
    }
    if (result case Ok(:final value)) {
      if (value.account != config.id ||
          value.fundingAmount != amount ||
          (expectedSourceWalletId != null &&
              value.sourceWalletId != expectedSourceWalletId)) {
        return Err(ArkSubmissionUncertainFailure(value.operationId));
      }
    }
    return result;
  }
}
