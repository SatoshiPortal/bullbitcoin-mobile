import 'exchange_event.dart';
import 'exchange_state.dart';

/// The exchange session table. A new session always starts from
/// [ExchangeLoading], so nothing of the previous account survives it; a
/// result for another session, or for an attempt that is not running, is a
/// stay.
ExchangeState transitionExchange(ExchangeState state, ExchangeEvent event) =>
    switch ((state, event)) {
      // Access decides which session, if any, the account belongs to.
      (ExchangeSignedOut(), ExchangeAccessChanged(:final access)) =>
        switch (access.signedInSession) {
          null => state,
          final session => ExchangeLoading(session),
        },
      (
        ExchangeLoading(:final session) ||
            ExchangeLoadFailed(:final session) ||
            ExchangeLoaded(:final session),
        ExchangeAccessChanged(:final access),
      ) =>
        switch (access.signedInSession) {
          null => const ExchangeSignedOut(),
          final next when next == session => state,
          final next => ExchangeLoading(next),
        },

      // Refresh: a retry after a failed load, or one refresh at a time.
      (ExchangeSignedOut() || ExchangeLoading(), ExchangeRefreshRequested()) =>
        state,
      (ExchangeLoadFailed(:final session), ExchangeRefreshRequested()) =>
        ExchangeLoading(session),
      (ExchangeLoaded(refresh: Refreshing()), ExchangeRefreshRequested()) =>
        state,
      (
        ExchangeLoaded(refresh: RefreshIdle() || RefreshFailed()),
        ExchangeRefreshRequested(),
      ) =>
        (state as ExchangeLoaded).copyWith(refresh: const Refreshing()),

      // Summary results.
      (
        ExchangeLoading(:final session),
        ExchangeSummaryLoaded(session: final from, :final summary),
      )
          when from == session =>
        ExchangeLoaded(
          session: session,
          summary: summary,
          announcements: const AnnouncementsLoading(),
          refresh: const RefreshIdle(),
          dcaStop: const DcaStopIdle(),
        ),
      (
        ExchangeLoading(:final session),
        ExchangeSummaryFailed(session: final from, :final failure),
      )
          when from == session =>
        ExchangeLoadFailed(session, failure),
      (
        ExchangeLoaded(:final session, refresh: Refreshing()),
        ExchangeSummaryLoaded(session: final from, :final summary),
      )
          when from == session =>
        (state as ExchangeLoaded).copyWith(
          summary: summary,
          refresh: const RefreshIdle(),
        ),
      (
        ExchangeLoaded(:final session, refresh: Refreshing()),
        ExchangeSummaryFailed(session: final from, :final failure),
      )
          when from == session =>
        (state as ExchangeLoaded).copyWith(refresh: RefreshFailed(failure)),
      (
        ExchangeSignedOut() ||
            ExchangeLoading() ||
            ExchangeLoadFailed() ||
            ExchangeLoaded(),
        ExchangeSummaryLoaded() || ExchangeSummaryFailed(),
      ) =>
        state,

      // Announcements, once per load.
      (
        ExchangeLoaded(:final session, announcements: AnnouncementsLoading()),
        ExchangeAnnouncementsLoaded(session: final from, :final items),
      )
          when from == session =>
        (state as ExchangeLoaded).copyWith(
          announcements: AnnouncementsShown(items),
        ),
      (
        ExchangeLoaded(:final session, announcements: AnnouncementsLoading()),
        ExchangeAnnouncementsFailed(session: final from, :final failure),
      )
          when from == session =>
        (state as ExchangeLoaded).copyWith(
          announcements: AnnouncementsUnavailable(failure),
        ),
      (
        ExchangeSignedOut() ||
            ExchangeLoading() ||
            ExchangeLoadFailed() ||
            ExchangeLoaded(),
        ExchangeAnnouncementsLoaded() || ExchangeAnnouncementsFailed(),
      ) =>
        state,

      // Stopping the recurring buy: one request at a time, then a refresh.
      (
        ExchangeLoaded(dcaStop: DcaStopIdle() || DcaStopFailed()),
        ExchangeStopDcaRequested(),
      ) =>
        (state as ExchangeLoaded).copyWith(dcaStop: const DcaStopping()),
      (
        ExchangeSignedOut() ||
            ExchangeLoading() ||
            ExchangeLoadFailed() ||
            ExchangeLoaded(dcaStop: DcaStopping()),
        ExchangeStopDcaRequested(),
      ) =>
        state,
      (
        ExchangeLoaded(:final session, dcaStop: DcaStopping()),
        ExchangeDcaStopped(session: final from),
      )
          when from == session =>
        (state as ExchangeLoaded).copyWith(
          dcaStop: const DcaStopIdle(),
          refresh: const Refreshing(),
        ),
      (
        ExchangeLoaded(:final session, dcaStop: DcaStopping()),
        ExchangeDcaStopFailed(session: final from, :final failure),
      )
          when from == session =>
        (state as ExchangeLoaded).copyWith(dcaStop: DcaStopFailed(failure)),
      (
        ExchangeSignedOut() ||
            ExchangeLoading() ||
            ExchangeLoadFailed() ||
            ExchangeLoaded(),
        ExchangeDcaStopped() || ExchangeDcaStopFailed(),
      ) =>
        state,
    };
