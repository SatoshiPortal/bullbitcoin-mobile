import 'package:bull_exchange/src/account/domain/usecases/get_user_summary_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/account/domain/usecases/get_account_usecase.dart';
import 'package:primitives/primitives.dart';

final class FakeGetUserSummaryUsecase implements GetUserSummaryUsecase {
  final Future<Result<UserSummary, ExchangeReadFailure>> Function(
    ExchangeSession session,
  )
  answer;

  FakeGetUserSummaryUsecase(this.answer);

  @override
  Future<Result<UserSummary, ExchangeReadFailure>> execute(
    ExchangeSession session,
  ) => answer(session);
}

final class FakeGetAccountUsecase implements GetAccountUsecase {
  final Future<Result<UserSummary, ExchangeFailure>> Function(
    ExchangeSession session,
  )
  answer;

  FakeGetAccountUsecase(this.answer);

  @override
  Future<Result<UserSummary, ExchangeFailure>> execute(
    ExchangeSession session,
  ) => answer(session);
}
