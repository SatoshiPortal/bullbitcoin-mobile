import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:primitives/primitives.dart';

import '../domain/entities/user_summary.dart';
import '../domain/exchange_failure.dart';
import 'bbx_api_user_summary_mapper.dart';
import 'exchange_call_classifier.dart';

/// The one classification of `getUserSummary`, shared by the account and the
/// user repositories: no account in the answer is [ExchangeMissingFailure], an answer
/// that can't be read or mapped is [ExchangeMalformedFailure], and only a 401 or a
/// missing or unreadable key is [ExchangeSessionRejectedFailure].
Future<Result<UserSummary, ExchangeReadFailure>> readUserSummary(bbx.Bbx api) =>
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
  Result<UserSummary, ExchangeReadFailure> read, {
  required ExchangeFailure Function() credentialUnavailable,
}) => switch (read) {
  Ok(:final value) => Ok(value),
  Err(failure: ExchangeMissingFailure()) => const Err(
    ExchangeAccountUnavailableFailure('getUserSummary: no account'),
  ),
  Err(
    failure: ExchangeSessionRejectedFailure(
      why: ExchangeSessionRejection.server,
    ),
  ) =>
    const Err(ExchangeSessionRejectedFailure(ExchangeSessionRejection.server)),
  Err(
    failure: ExchangeSessionRejectedFailure(
      why: ExchangeSessionRejection.signedOut,
    ),
  ) =>
    const Err(ExchangeNotAuthenticatedFailure()),
  Err(
    failure: ExchangeSessionRejectedFailure(
      why: ExchangeSessionRejection.credentialUnavailable,
    ),
  ) =>
    Err(credentialUnavailable()),
  Err(
    failure: ExchangeSessionRejectedFailure(
      why: ExchangeSessionRejection.sessionChanged,
    ),
  ) =>
    const Err(ExchangeOperationStaleFailure()),
  Err(failure: ExchangeUnreachableFailure(isNetwork: true, :final reason)) =>
    Err(ExchangeNetworkFailure('getUserSummary unreachable: $reason')),
  Err(failure: ExchangeUnreachableFailure(isNetwork: false)) => const Err(
    ExchangeAccountUnavailableFailure(),
  ),
  Err(failure: ExchangeMalformedFailure(:final reason)) => Err(
    ExchangeAccountUnavailableFailure('getUserSummary failed: $reason'),
  ),
};
