import 'package:bull_exchange/src/funding/domain/usecases/get_cop_funding_institutions_usecase.dart';
import 'package:bull_exchange/src/funding/domain/usecases/get_funding_account_usecase.dart';
import 'package:bull_exchange/src/funding/domain/usecases/get_funding_consent_usecase.dart';
import 'package:bull_exchange/src/funding/domain/usecases/get_funding_instructions_usecase.dart';
import 'package:bull_exchange/src/funding/domain/usecases/save_funding_consent_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/funding.dart';
import 'package:primitives/primitives.dart';

final class FakeGetFundingAccountUsecase implements GetFundingAccountUsecase {
  final Future<Result<FundingAccount, ExchangeReadFailure>> Function(
    ExchangeSession session,
  )
  answer;

  FakeGetFundingAccountUsecase(this.answer);

  @override
  Future<Result<FundingAccount, ExchangeReadFailure>> execute(
    ExchangeSession session,
  ) => answer(session);
}

final class FakeSaveFundingConsentUsecase implements SaveFundingConsentUsecase {
  final Future<Result<void, ExchangeWriteFailure>> Function(
    ExchangeSession session,
  )
  answer;

  FakeSaveFundingConsentUsecase(this.answer);

  @override
  Future<Result<void, ExchangeWriteFailure>> execute(ExchangeSession session) =>
      answer(session);
}

final class FakeGetFundingConsentUsecase implements GetFundingConsentUsecase {
  final Future<Result<bool, ExchangeReadFailure>> Function(
    ExchangeSession session,
  )
  answer;

  FakeGetFundingConsentUsecase(this.answer);

  @override
  Future<Result<bool, ExchangeReadFailure>> execute(ExchangeSession session) =>
      answer(session);
}

final class FakeGetCopFundingInstitutionsUsecase
    implements GetCopFundingInstitutionsUsecase {
  final Future<Result<List<FundingInstitution>, ExchangeReadFailure>> Function(
    ExchangeSession session,
  )
  answer;

  FakeGetCopFundingInstitutionsUsecase(this.answer);

  @override
  Future<Result<List<FundingInstitution>, ExchangeReadFailure>> execute(
    ExchangeSession session,
  ) => answer(session);
}

final class FakeGetFundingInstructionsUsecase
    implements GetFundingInstructionsUsecase {
  final Future<Result<FundingAnswer, ExchangeReadFailure>> Function(
    ExchangeSession session,
    FundingRequest request,
  )
  answer;

  FakeGetFundingInstructionsUsecase(this.answer);

  @override
  Future<Result<FundingAnswer, ExchangeReadFailure>> execute(
    ExchangeSession session,
    FundingRequest request,
  ) => answer(session, request);
}
