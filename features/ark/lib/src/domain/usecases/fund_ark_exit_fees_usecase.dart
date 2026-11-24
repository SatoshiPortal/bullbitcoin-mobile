import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_exit_funding.dart';
import '../ark_failure.dart';
import '../ark_reserve_top_up_port.dart';

/// Pays a waiting emergency exit's fees from Secure Bitcoin, as Bark pays
/// them from its on-chain wallet: Secure Bitcoin sends what the reserve
/// lacks, and the exit continues once that confirms. Without the funds, the
/// exit waits and [ArkExitFunding.needed] says how much to add.
final class FundArkExitFeesUsecase {
  /// Never a dust coin: the reserve's coin must itself be spendable.
  static final minimum = Sats.fromInt(1000);

  /// How long a sent top-up may take to show in the reserve before another
  /// is considered.
  static const settling = Duration(minutes: 3);

  final ArkReserveTopUpPort _port;
  final ArkExitFunding _funding;
  final DateTime Function() _now;

  FundArkExitFeesUsecase(this._port, this._funding, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  Future<Result<void, ArkFailure>> execute(
    ArkAccountId account, {
    required String? reserveAddress,
    required ArkExitAwaitingFeesFailure short,
  }) async {
    final lacking = short.missing.value - short.incoming.value;
    // What is already on its way covers it: wait for it to confirm.
    if (lacking <= BigInt.zero) {
      _funding.waitFor(null);
      return const Ok(null);
    }
    final now = _now();
    if (_funding.sentWithin(settling, now)) return const Ok(null);
    if (reserveAddress == null || reserveAddress.isEmpty) {
      return const Err(ArkServiceUnavailableFailure());
    }
    final amount = Sats(lacking < minimum.value ? minimum.value : lacking);
    switch (await _port.topUp(
      account,
      address: reserveAddress,
      amount: amount,
    )) {
      case Ok():
        _funding.sent(now);
        _funding.waitFor(null);
        return const Ok(null);
      case Err(failure: ArkPaymentInsufficientFundsFailure()):
        // Secure Bitcoin cannot pay yet: the exit waits for it.
        _funding.waitFor(amount);
        return const Ok(null);
      case Err(failure: final ArkSubmissionUncertainFailure uncertain):
        // It may have left: never send a second one before it could show.
        _funding.sent(now);
        return Err(uncertain);
      case Err(:final failure):
        return Err(failure);
    }
  }
}
