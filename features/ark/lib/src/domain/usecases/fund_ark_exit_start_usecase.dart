import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_exit_funding.dart';
import '../ark_failure.dart';
import '../ark_reserve_top_up_port.dart';
import 'fund_ark_exit_fees_usecase.dart';

/// Makes sure an emergency exit can pay its broadcast fees before it starts:
/// when the confirmed reserve does not cover the fresh [ArkQuote]'s fee,
/// Secure Bitcoin sends what is missing. When Secure Bitcoin cannot, the
/// exit does not start, since it could not move forward without fees.
final class FundArkExitStartUsecase {
  final ArkReserveTopUpPort _port;
  final ArkExitFunding _funding;
  final DateTime Function() _now;

  FundArkExitStartUsecase(this._port, this._funding, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// What the reserve lacks for [quote]'s fee, never below a spendable coin;
  /// null when it is covered.
  static Sats? shortfall(ArkQuote quote) {
    final reserve = quote.confirmedReserveExposure ?? Sats.zero;
    final short = quote.fee.value - reserve.value;
    if (short <= BigInt.zero) return null;
    final minimum = FundArkExitFeesUsecase.minimum.value;
    return Sats(short < minimum ? minimum : short);
  }

  Future<Result<void, ArkFailure>> execute(
    ArkAccountId account, {
    required ArkQuote quote,
    required String? reserveAddress,
  }) async {
    final amount = shortfall(quote);
    if (amount == null) return const Ok(null);
    final now = _now();
    // A top-up still on its way covers it: the exit waits for it to confirm.
    if (_funding.sentWithin(FundArkExitFeesUsecase.settling, now)) {
      return const Ok(null);
    }
    if (reserveAddress == null || reserveAddress.isEmpty) {
      return const Err(ArkServiceUnavailableFailure());
    }
    switch (await _port.topUp(
      account,
      address: reserveAddress,
      amount: amount,
    )) {
      case Ok():
        _funding.sent(now);
        return const Ok(null);
      case Err(failure: ArkPaymentInsufficientFundsFailure()):
        return Err(ArkExitFeesUnfundedFailure(amount));
      case Err(failure: final ArkSubmissionUncertainFailure uncertain):
        // It may have left: never send a second one before it could show.
        _funding.sent(now);
        return Err(uncertain);
      case Err(:final failure):
        return Err(failure);
    }
  }
}
