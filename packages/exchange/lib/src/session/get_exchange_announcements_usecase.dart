import '../setup/exchange_access_lifecycle.dart';

import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';

import 'package:meta/meta.dart';

/// Reads the announcement banner of [execute]'s session. The repository
/// sanitizes; this refuses a session that is no longer current and lifts the
/// core failure into the feature's family.
class GetExchangeAnnouncementsUsecase {
  final Exchange _exchange;
  final ExchangeAccessLifecycle _access;

  const GetExchangeAnnouncementsUsecase({
    required this._exchange,
    required this._access,
  });

  @useResult
  Future<Result<List<Announcement>, ExchangeFailure>> execute(
    ExchangeSession session,
  ) async {
    if (_access.session != session) {
      return const Err(ExchangeOperationStaleFailure());
    }
    final result = await _exchange.listAnnouncements(session.environment);
    if (_access.session != session) {
      return const Err(ExchangeOperationStaleFailure());
    }
    return result.mapErr(
      (failure) => ExchangeAnnouncementsUnavailableFailure(failure.logMessage),
    );
  }
}
