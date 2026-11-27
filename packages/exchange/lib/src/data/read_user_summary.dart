import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:primitives/primitives.dart';

import '../domain/entities/user_summary.dart';
import '../domain/exchange_call_result.dart';
import '../domain/exchange_failure.dart';
import 'bbx_api_user_summary_mapper.dart';
import 'exchange_call_classifier.dart';

/// The one classification of `getUserSummary`, shared by the account and the
/// user repositories: no account in the answer is [ReadMissing], an answer
/// that can't be read or mapped is [ReadMalformed], and only a 401 or a
/// missing or unreadable key is [ReadSessionRejected].
Future<ExchangeRead<UserSummary>> readUserSummary(bbx.Bbx api) =>
    exchangeRead<bbx.UserSummary, UserSummary>(
      'getUserSummary',
      api.users.getUserSummary,
      userSummaryFromBbxApi,
    );

/// [read] as the repositories' result. An empty or refused answer is
/// [ExchangeAccountUnavailableFailure], never "signed out": only a 401
/// ([ExchangeSessionRejectedFailure]) or a missing key
/// ([ExchangeNotAuthenticatedFailure]) is. [credentialUnavailable] is the
/// caller's failure for a key that could not be read.
Result<UserSummary, ExchangeFailure> userSummaryResult(
  ExchangeRead<UserSummary> read, {
  required ExchangeFailure Function() credentialUnavailable,
}) => switch (read) {
  ReadGot(:final value) => Ok(value),
  ReadMissing() => const Err(
    ExchangeAccountUnavailableFailure('getUserSummary: no account'),
  ),
  ReadSessionRejected(why: ExchangeSessionRejection.server) => const Err(
    ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
  ),
  ReadSessionRejected(why: ExchangeSessionRejection.signedOut) => const Err(
    ExchangeNotAuthenticatedFailure(),
  ),
  ReadSessionRejected(why: ExchangeSessionRejection.credentialUnavailable) =>
    Err(credentialUnavailable()),
  ReadSessionRejected(why: ExchangeSessionRejection.sessionChanged) =>
    const Err(ExchangeOperationStaleFailure()),
  ReadUnreachable(isNetwork: true, :final reason) => Err(
    ExchangeNetworkFailure('getUserSummary unreachable: $reason'),
  ),
  ReadUnreachable(isNetwork: false) => const Err(
    ExchangeAccountUnavailableFailure(),
  ),
  ReadMalformed(:final reason) => Err(
    ExchangeAccountUnavailableFailure('getUserSummary failed: $reason'),
  ),
};
