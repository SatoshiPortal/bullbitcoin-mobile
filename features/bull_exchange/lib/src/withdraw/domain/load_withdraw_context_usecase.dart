import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/withdraw/domain/withdraw_failure.dart';
import 'package:meta/meta.dart';

class LoadWithdrawContextUsecase {
  final Exchange _exchange;

  const LoadWithdrawContextUsecase(this._exchange);

  /// Loads the account currency, limits and restrictions before entry.
  @useResult
  Future<Result<UserSummary, WithdrawFailure>> execute() async {
    return (await _exchange.getUserSummary()).mapErr((failure) {
      if (failure
          case ExchangeNotAuthenticatedFailure() ||
              ExchangeSessionRejectedFailure() ||
              ExchangeCredentialReadFailure()) {
        return const WithdrawUnauthenticatedFailure();
      }
      return WithdrawUnexpectedFailure(failure.runtimeType.toString());
    });
  }
}
