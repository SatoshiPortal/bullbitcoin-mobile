import 'package:meta/meta.dart';

import '../../funding/funding_request.dart';
import '../catalog/jurisdiction.dart';
import '../entities/funding_institution.dart';
import '../exchange_access.dart';
import '../exchange_call_result.dart';

/// The funding calls, each tied to the [ExchangeSession] the flow opened
/// with and answering a closed result.
abstract interface class FundingRepository {
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
