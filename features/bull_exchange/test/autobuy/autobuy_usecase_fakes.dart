import 'package:bull_exchange/src/autobuy/domain/autobuy_state.dart';
import 'package:bull_exchange/src/autobuy/domain/usecases/load_autobuy_context_usecase.dart';
import 'package:bull_exchange/src/autobuy/domain/usecases/save_autobuy_preference_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';

final class FakeLoadAutoBuyContextUsecase implements LoadAutoBuyContextUsecase {
  final Future<Result<AutoBuyContext, ExchangeReadFailure>> Function(
    ExchangeSession session,
  )
  answer;

  FakeLoadAutoBuyContextUsecase(this.answer);

  @override
  Future<Result<AutoBuyContext, ExchangeReadFailure>> execute(
    ExchangeSession session,
  ) => answer(session);
}

final class FakeSaveAutoBuyPreferenceUsecase
    implements SaveAutoBuyPreferenceUsecase {
  final Future<ConfirmAnswered<AutoBuyTarget, bool>> Function(
    ExchangeSession session,
    ConfirmSend<AutoBuyTarget> effect,
  )
  answer;

  FakeSaveAutoBuyPreferenceUsecase(this.answer);

  @override
  Future<ConfirmAnswered<AutoBuyTarget, bool>> execute(
    ExchangeSession session,
    ConfirmSend<AutoBuyTarget> effect,
  ) => answer(session, effect);
}
