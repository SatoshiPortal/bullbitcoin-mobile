import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';

/// Inputs of the exchange session machine: access changes, user intents and
/// effect results. Every result names the session that started it.
@immutable
sealed class ExchangeEvent {
  const ExchangeEvent();
}

final class ExchangeAccessChanged extends ExchangeEvent {
  final ExchangeAccess access;

  const ExchangeAccessChanged(this.access);
}

/// Pull to refresh, Retry, a push saying the account changed, or the app
/// coming back.
final class ExchangeRefreshRequested extends ExchangeEvent {
  const ExchangeRefreshRequested();
}

final class ExchangeSummaryLoaded extends ExchangeEvent {
  final ExchangeSession session;
  final UserSummary summary;

  const ExchangeSummaryLoaded(this.session, this.summary);
}

final class ExchangeSummaryFailed extends ExchangeEvent {
  final ExchangeSession session;
  final ExchangeFailure failure;

  const ExchangeSummaryFailed(this.session, this.failure);
}

final class ExchangeAnnouncementsLoaded extends ExchangeEvent {
  final ExchangeSession session;
  final List<Announcement> items;

  const ExchangeAnnouncementsLoaded(this.session, this.items);
}

final class ExchangeAnnouncementsFailed extends ExchangeEvent {
  final ExchangeSession session;
  final ExchangeFailure failure;

  const ExchangeAnnouncementsFailed(this.session, this.failure);
}

final class ExchangeStopDcaRequested extends ExchangeEvent {
  const ExchangeStopDcaRequested();
}

final class ExchangeDcaStopped extends ExchangeEvent {
  final ExchangeSession session;

  const ExchangeDcaStopped(this.session);
}

final class ExchangeDcaStopFailed extends ExchangeEvent {
  final ExchangeSession session;
  final ExchangeFailure failure;

  const ExchangeDcaStopFailed(this.session, this.failure);
}
