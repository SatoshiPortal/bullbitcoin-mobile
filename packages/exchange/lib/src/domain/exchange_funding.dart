import 'package:meta/meta.dart';

import '../funding/funding_request.dart';
import 'catalog/jurisdiction.dart';
import 'entities/funding_institution.dart';
import 'exchange_access.dart';
import 'exchange_call_result.dart';

/// The funding calls, each tied to the [ExchangeSession] the flow opened
/// with and answering a closed result.
abstract interface class ExchangeFunding {
  /// The account facts the fund flow decides from.
  @useResult
  Future<ExchangeRead<FundingAccount>> account(ExchangeSession session);

  /// A rail's instructions, or the exchange's refusal.
  @useResult
  Future<ExchangeRead<FundingAnswer>> instructions(
    ExchangeSession session,
    FundingRequest request,
  );

  /// The banks of [jurisdiction] (COP). An empty list is an answer.
  @useResult
  Future<ExchangeRead<List<FundingInstitution>>> institutions(
    ExchangeSession session,
    Jurisdiction jurisdiction,
  );

  /// Records the scam-warning consent.
  @useResult
  Future<ExchangeWrite<void>> consent(ExchangeSession session);

  /// Whether the consent is on the account (the re-read after an unknown
  /// consent write).
  @useResult
  Future<ExchangeRead<bool>> consentOnAccount(ExchangeSession session);
}

final class ExchangeFundingImpl implements ExchangeFunding {
  final Future<ExchangeRead<FundingAccount>> Function(ExchangeSession) _account;
  final Future<ExchangeRead<FundingAnswer>> Function(
    ExchangeSession,
    FundingRequest,
  )
  _instructions;
  final Future<ExchangeRead<List<FundingInstitution>>> Function(
    ExchangeSession,
    Jurisdiction,
  )
  _institutions;
  final Future<ExchangeWrite<void>> Function(ExchangeSession) _consent;
  final Future<ExchangeRead<bool>> Function(ExchangeSession) _consentOnAccount;

  const ExchangeFundingImpl({
    required this._account,
    required this._instructions,
    required this._institutions,
    required this._consent,
    required this._consentOnAccount,
  });

  @override
  Future<ExchangeRead<FundingAccount>> account(ExchangeSession session) =>
      _account(session);

  @override
  Future<ExchangeRead<FundingAnswer>> instructions(
    ExchangeSession session,
    FundingRequest request,
  ) => _instructions(session, request);

  @override
  Future<ExchangeRead<List<FundingInstitution>>> institutions(
    ExchangeSession session,
    Jurisdiction jurisdiction,
  ) => _institutions(session, jurisdiction);

  @override
  Future<ExchangeWrite<void>> consent(ExchangeSession session) =>
      _consent(session);

  @override
  Future<ExchangeRead<bool>> consentOnAccount(ExchangeSession session) =>
      _consentOnAccount(session);
}
