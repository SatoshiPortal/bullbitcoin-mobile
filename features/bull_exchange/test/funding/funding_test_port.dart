import 'package:exchange/exchange.dart';
import 'package:exchange/funding.dart';
import 'package:primitives/primitives.dart';

/// The funding calls of one test: each answers what it was given and
/// throws when the test gave none; every call is logged with the session
/// it got.
final class FundingTestPort implements FundingRepository {
  Result<FundingAccount, ExchangeReadFailure>? accountAnswer;
  Result<FundingAnswer, ExchangeReadFailure>? instructionsAnswer;
  Result<List<FundingInstitution>, ExchangeReadFailure>? institutionsAnswer;
  Result<void, ExchangeWriteFailure>? consentAnswer;
  Result<bool, ExchangeReadFailure>? consentOnAccountAnswer;
  final log = <String>[];

  T _given<T>(T? answer, String call) =>
      answer ?? (throw StateError('unexpected $call'));

  void _called(ExchangeSession session, String call) =>
      log.add('$call ${session.sessionId}');

  @override
  Future<Result<FundingAccount, ExchangeReadFailure>> account(
    ExchangeSession session,
  ) async {
    _called(session, 'account');
    return _given(accountAnswer, 'account');
  }

  @override
  Future<Result<FundingAnswer, ExchangeReadFailure>> instructions(
    ExchangeSession session,
    FundingRequest request,
  ) async {
    _called(session, 'instructions ${request.rail.name}');
    return _given(instructionsAnswer, 'instructions');
  }

  @override
  Future<Result<List<FundingInstitution>, ExchangeReadFailure>> institutions(
    ExchangeSession session,
    Jurisdiction jurisdiction,
  ) async {
    _called(session, 'institutions ${jurisdiction.code}');
    return _given(institutionsAnswer, 'institutions');
  }

  @override
  Future<Result<void, ExchangeWriteFailure>> consent(
    ExchangeSession session,
  ) async {
    _called(session, 'consent');
    return _given(consentAnswer, 'consent');
  }

  @override
  Future<Result<bool, ExchangeReadFailure>> consentOnAccount(
    ExchangeSession session,
  ) async {
    _called(session, 'consentOnAccount');
    return _given(consentOnAccountAnswer, 'consentOnAccount');
  }
}

const fundingSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 0,
  sessionId: 'a',
);

FundingAccount fundingAccount({bool consented = true}) => FundingAccount(
  userNumber: 7,
  firstName: 'Ada',
  lastName: 'Lovelace',
  currency: ExchangeCatalog.parse('CAD'),
  restricted: false,
  consented: consented,
  confidentialSepa: ConfidentialSepaAvailability.unavailable,
);
