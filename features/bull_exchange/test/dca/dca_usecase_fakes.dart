import 'package:bull_exchange/src/dca/domain/dca_flow.dart';
import 'package:bull_exchange/src/dca/domain/usecases/activate_dca_usecase.dart';
import 'package:bull_exchange/src/dca/domain/usecases/create_dca_usecase.dart';
import 'package:bull_exchange/src/dca/domain/usecases/load_dca_context_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:bull_exchange/src/dca/domain/usecases/stop_dca_usecase.dart';
import 'package:primitives/primitives.dart';

final class FakeLoadDcaContextUsecase implements LoadDcaContextUsecase {
  final Future<ExchangeRead<DcaContext>> Function(ExchangeSession session)
  answer;

  FakeLoadDcaContextUsecase(this.answer);

  @override
  Future<ExchangeRead<DcaContext>> execute(ExchangeSession session) =>
      answer(session);
}

final class FakeCreateDcaUsecase implements CreateDcaUsecase {
  final Future<ConfirmAnswered<DcaPlan, DcaPlan>> Function(
    ExchangeSession session,
    ConfirmSend<DcaPlan> effect,
  )
  answer;

  FakeCreateDcaUsecase(this.answer);

  @override
  Future<ConfirmAnswered<DcaPlan, DcaPlan>> execute(
    ExchangeSession session,
    ConfirmSend<DcaPlan> effect,
  ) => answer(session, effect);
}

final class FakeActivateDcaUsecase implements ActivateDcaUsecase {
  final Future<void> Function() answer;

  FakeActivateDcaUsecase(this.answer);

  @override
  Future<void> execute() => answer();
}

final class FakeStopDcaUsecase implements StopDcaUsecase {
  final Future<Result<void, ExchangeFailure>> Function(ExchangeSession session)
  answer;

  FakeStopDcaUsecase(this.answer);

  @override
  Future<Result<void, ExchangeFailure>> execute(ExchangeSession session) =>
      answer(session);
}
