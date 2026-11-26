import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_board_funding_port.dart';
import '../repositories/ark_preferences_repository.dart';

final class PrepareArkBoardUsecase {
  /// A busy Ark wallet (an exit or renewal pass holding it) is waited out,
  /// and a stale price prepared again, this many times before the user is
  /// told; busy attempts are this long apart.
  static const busyAttempts = 5;
  static const busyDelay = Duration(seconds: 1);

  final ArkBoardFundingPort _funding;
  final ArkPreferencesRepository _preferences;
  final Future<void> Function(Duration) _wait;

  PrepareArkBoardUsecase(
    this._funding,
    this._preferences, {
    Future<void> Function(Duration)? wait,
  }) : _wait = wait ?? Future<void>.delayed;

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
    Future<Result<ArkBoardPreparation, ArkFailure>> prepare() async =>
        switch ((expectedSourceWalletId, _funding)) {
          (null, final funding) => await funding.prepare(config, amount),
          (final source?, ArkTransferBoardFundingPort funding) =>
            await funding.prepareFrom(config, amount, sourceWalletId: source),
          _ => const Err(ArkServiceUnavailableFailure()),
        };
    // A busy or stale refusal released everything it held: preparing again
    // is safe. Busy is waited out; a stale price (a block landed while it
    // was being prepared) is simply priced again.
    var result = await prepare();
    for (
      var attempt = 1;
      attempt < busyAttempts && result is Err<ArkBoardPreparation, ArkFailure>;
      attempt++
    ) {
      switch (result) {
        case Err(failure: ArkOperationBusyFailure()):
          await _wait(busyDelay);
          result = await prepare();
        case Err(failure: ArkReviewExpiredFailure()):
          result = await prepare();
        default:
          attempt = busyAttempts;
      }
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
