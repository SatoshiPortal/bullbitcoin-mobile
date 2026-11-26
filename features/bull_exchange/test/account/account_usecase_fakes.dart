import 'package:bull_exchange/src/account/domain/usecases/get_user_summary_usecase.dart';
import 'package:exchange/exchange.dart';

final class FakeGetUserSummaryUsecase implements GetUserSummaryUsecase {
  final Future<ExchangeRead<UserSummary>> Function(ExchangeSession session)
  answer;

  FakeGetUserSummaryUsecase(this.answer);

  @override
  Future<ExchangeRead<UserSummary>> execute(ExchangeSession session) =>
      answer(session);
}
