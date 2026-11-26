import 'package:bull_exchange/src/funding/domain/usecases/get_cop_funding_institutions_usecase.dart';
import 'package:bull_exchange/src/funding/domain/usecases/get_funding_account_usecase.dart';
import 'package:bull_exchange/src/funding/domain/usecases/get_funding_consent_usecase.dart';
import 'package:bull_exchange/src/funding/domain/usecases/get_funding_instructions_usecase.dart';
import 'package:bull_exchange/src/funding/domain/usecases/save_funding_consent_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/funding.dart';

final class FakeGetFundingAccountUsecase implements GetFundingAccountUsecase {
  final Future<ExchangeRead<FundingAccount>> Function(ExchangeSession session)
  answer;

  FakeGetFundingAccountUsecase(this.answer);

  @override
  Future<ExchangeRead<FundingAccount>> execute(ExchangeSession session) =>
      answer(session);
}

final class FakeSaveFundingConsentUsecase implements SaveFundingConsentUsecase {
  final Future<ExchangeWrite<void>> Function(ExchangeSession session) answer;

  FakeSaveFundingConsentUsecase(this.answer);

  @override
  Future<ExchangeWrite<void>> execute(ExchangeSession session) =>
      answer(session);
}

final class FakeGetFundingConsentUsecase implements GetFundingConsentUsecase {
  final Future<ExchangeRead<bool>> Function(ExchangeSession session) answer;

  FakeGetFundingConsentUsecase(this.answer);

  @override
  Future<ExchangeRead<bool>> execute(ExchangeSession session) =>
      answer(session);
}

final class FakeGetCopFundingInstitutionsUsecase
    implements GetCopFundingInstitutionsUsecase {
  final Future<ExchangeRead<List<FundingInstitution>>> Function(
    ExchangeSession session,
  )
  answer;

  FakeGetCopFundingInstitutionsUsecase(this.answer);

  @override
  Future<ExchangeRead<List<FundingInstitution>>> execute(
    ExchangeSession session,
  ) => answer(session);
}

final class FakeGetFundingInstructionsUsecase
    implements GetFundingInstructionsUsecase {
  final Future<ExchangeRead<FundingAnswer>> Function(
    ExchangeSession session,
    FundingRequest request,
  )
  answer;

  FakeGetFundingInstructionsUsecase(this.answer);

  @override
  Future<ExchangeRead<FundingAnswer>> execute(
    ExchangeSession session,
    FundingRequest request,
  ) => answer(session, request);
}
