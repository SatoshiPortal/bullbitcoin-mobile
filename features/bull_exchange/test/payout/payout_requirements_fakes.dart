import 'package:bull_exchange/src/payout/domain/usecases/activate_virtual_payee_usecase.dart';
import 'package:bull_exchange/src/payout/domain/usecases/create_virtual_iban_usecase.dart';
import 'package:bull_exchange/src/payout/domain/usecases/find_virtual_iban_usecase.dart';
import 'package:bull_exchange/src/payout/domain/usecases/get_virtual_payee_status_usecase.dart';
import 'package:bull_exchange/src/payout/domain/usecases/load_virtual_iban_context_usecase.dart';
import 'package:bull_exchange/src/payout/payout_requirements_runner.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';

final class FakeLoadVirtualIbanContextUsecase
    implements LoadVirtualIbanContextUsecase {
  final Future<Result<VirtualIbanContext, ExchangeReadFailure>> Function(
    ExchangeSession session,
  )
  answer;

  FakeLoadVirtualIbanContextUsecase(this.answer);

  @override
  Future<Result<VirtualIbanContext, ExchangeReadFailure>> execute(
    ExchangeSession session,
  ) => answer(session);
}

final class FakeCreateVirtualIbanUsecase implements CreateVirtualIbanUsecase {
  final Future<Result<VirtualIban, ExchangeWriteFailure>> Function(
    ExchangeSession session,
  )
  answer;

  FakeCreateVirtualIbanUsecase(this.answer);

  @override
  Future<Result<VirtualIban, ExchangeWriteFailure>> execute(
    ExchangeSession session,
  ) => answer(session);
}

final class FakeFindVirtualIbanUsecase implements FindVirtualIbanUsecase {
  final Future<Result<VirtualIban?, ExchangeReadFailure>> Function(
    ExchangeSession session,
  )
  answer;

  FakeFindVirtualIbanUsecase(this.answer);

  @override
  Future<Result<VirtualIban?, ExchangeReadFailure>> execute(
    ExchangeSession session,
  ) => answer(session);
}

final class FakeGetVirtualPayeeStatusUsecase
    implements GetVirtualPayeeStatusUsecase {
  final Future<Result<SepaVirtualPayeeStatus, ExchangeReadFailure>> Function(
    ExchangeSession session,
    String recipientId,
  )
  answer;

  FakeGetVirtualPayeeStatusUsecase(this.answer);

  @override
  Future<Result<SepaVirtualPayeeStatus, ExchangeReadFailure>> execute(
    ExchangeSession session,
    String recipientId,
  ) => answer(session, recipientId);
}

final class FakeActivateVirtualPayeeUsecase
    implements ActivateVirtualPayeeUsecase {
  final Future<Result<SepaVirtualPayeeStatus, ExchangeWriteFailure>> Function(
    ExchangeSession session,
    String recipientId,
  )
  answer;

  FakeActivateVirtualPayeeUsecase(this.answer);

  @override
  Future<Result<SepaVirtualPayeeStatus, ExchangeWriteFailure>> execute(
    ExchangeSession session,
    String recipientId,
  ) => answer(session, recipientId);
}

/// Requirements for a flow test that never reaches a virtual IBAN or payee
/// requirement: any call fails the test.
PayoutRequirementsUsecases unusedPayoutRequirements() =>
    PayoutRequirementsUsecases(
      loadVirtualIban: FakeLoadVirtualIbanContextUsecase(
        (_) => throw StateError('no virtual IBAN in this test'),
      ),
      createVirtualIban: FakeCreateVirtualIbanUsecase(
        (_) => throw StateError('no virtual IBAN in this test'),
      ),
      findVirtualIban: FakeFindVirtualIbanUsecase(
        (_) => throw StateError('no virtual IBAN in this test'),
      ),
      payeeStatus: FakeGetVirtualPayeeStatusUsecase(
        (_, _) => throw StateError('no payee in this test'),
      ),
      activatePayee: FakeActivateVirtualPayeeUsecase(
        (_, _) => throw StateError('no payee in this test'),
      ),
    );
