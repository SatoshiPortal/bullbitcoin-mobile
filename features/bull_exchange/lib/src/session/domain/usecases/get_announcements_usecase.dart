import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Reads the announcement banner of the session; a session that is no longer
/// current is refused.
class GetAnnouncementsUsecase {
  final Exchange _exchange;

  const GetAnnouncementsUsecase(this._exchange);

  Future<Result<List<Announcement>, ExchangeFailure>> execute(
    ExchangeSession session,
  ) => _exchange.loadAnnouncements(session);
}
