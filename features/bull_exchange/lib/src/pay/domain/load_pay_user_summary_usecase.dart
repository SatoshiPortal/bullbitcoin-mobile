import 'package:bull_exchange/src/payin/payin_account.dart';
import 'package:bull_exchange/src/pay/domain/pay_failure.dart';
import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class LoadPayUserSummaryUsecase {
  final PayinAccount _account;
  const LoadPayUserSummaryUsecase(this._account);

  @useResult
  Future<Result<UserSummary, PayFailure>> execute() async =>
      (await _account.summary())
          .map((value) => value.userSummary)
          .mapErr(
            (failure) => PayUnexpectedFailure(
              'Summary unavailable: ${failure.runtimeType}',
            ),
          );
}
