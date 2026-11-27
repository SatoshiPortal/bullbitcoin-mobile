import 'package:meta/meta.dart';

import '../../funding/funding_request.dart';
import '../catalog/jurisdiction.dart';
import '../entities/funding_institution.dart';
import '../exchange_access.dart';
import '../exchange_failure.dart';

import 'package:primitives/primitives.dart';

/// The funding calls, each tied to the [ExchangeSession] the flow opened
/// with and answering a closed result.
abstract interface class FundingRepository {
  /// The account facts the fund flow decides from.
  @useResult
  Future<Result<FundingAccount, ExchangeReadFailure>> account(
    ExchangeSession session,
  );

  /// A rail's instructions, or the exchange's refusal.
  @useResult
  Future<Result<FundingAnswer, ExchangeReadFailure>> instructions(
    ExchangeSession session,
    FundingRequest request,
  );

  /// The banks of [jurisdiction] (COP). An empty list is an answer.
  @useResult
  Future<Result<List<FundingInstitution>, ExchangeReadFailure>> institutions(
    ExchangeSession session,
    Jurisdiction jurisdiction,
  );

  /// Records the scam-warning consent.
  @useResult
  Future<Result<void, ExchangeWriteFailure>> consent(ExchangeSession session);

  /// Whether the consent is on the account (the re-read after an unknown
  /// consent write).
  @useResult
  Future<Result<bool, ExchangeReadFailure>> consentOnAccount(
    ExchangeSession session,
  );
}
