import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

import 'exchange_event.dart';
import 'exchange_machine.dart';
import 'exchange_state.dart';

/// Shell of [transitionExchange]: applies events one at a time and starts
/// the effects of the state it enters. Each effect result carries the
/// session that started it.
class ExchangeBloc extends Bloc<ExchangeEvent, ExchangeState> {
  ExchangeBloc({
    required this._getAccount,
    required this._getAnnouncements,
    required this._stopDca,
    required ExchangeAccess Function() currentAccess,
    required Stream<ExchangeAccess> accessChanges,
    required Stream<NotificationMessage> accountChanges,
    Future<void> Function()? reconcileUnknownWrites,
  }) : _reconcileUnknownWrites = reconcileUnknownWrites ?? _nothing,
       super(const ExchangeSignedOut()) {
    on<ExchangeEvent>(_onEvent, transformer: sequential());
    add(ExchangeAccessChanged(currentAccess()));
    _access = accessChanges.listen((access) {
      if (!isClosed) add(ExchangeAccessChanged(access));
    });
    _notifications = accountChanges.listen((_) {
      if (!isClosed) add(const ExchangeRefreshRequested());
    });
  }

  final Future<Result<UserSummary, ExchangeFailure>> Function(ExchangeSession)
  _getAccount;
  final Future<Result<List<Announcement>, ExchangeFailure>> Function(
    ExchangeSession,
  )
  _getAnnouncements;
  final Future<Result<void, ExchangeFailure>> Function(ExchangeSession)
  _stopDca;
  final Future<void> Function() _reconcileUnknownWrites;
  StreamSubscription<ExchangeAccess>? _access;
  StreamSubscription<NotificationMessage>? _notifications;

  static Future<void> _nothing() async {}

  void _onEvent(ExchangeEvent event, Emitter<ExchangeState> emit) {
    final previous = state;
    final next = transitionExchange(previous, event);
    if (next == previous) return;
    emit(next);
    _runEffects(previous, next);
  }

  void _runEffects(ExchangeState previous, ExchangeState next) {
    switch (next) {
      case ExchangeLoading(:final session):
        if (previous.session != session) {
          // Settles writes whose outcome was unknown by re-reading them;
          // never sends them again.
          unawaited(_reconcileUnknownWrites());
        }
        unawaited(_loadSummary(session));
      case ExchangeLoaded(
        :final session,
        :final refresh,
        :final announcements,
        :final dcaStop,
      ):
        final ExchangeLoaded? before =
            previous is ExchangeLoaded && previous.session == session
            ? previous
            : null;
        if (refresh is Refreshing && before?.refresh is! Refreshing) {
          unawaited(_loadSummary(session));
        }
        if (announcements is AnnouncementsLoading &&
            before?.announcements is! AnnouncementsLoading) {
          unawaited(_loadAnnouncements(session));
        }
        if (dcaStop is DcaStopping && before?.dcaStop is! DcaStopping) {
          unawaited(_stopRecurringBuy(session));
        }
      case ExchangeSignedOut() || ExchangeLoadFailed():
        return;
    }
  }

  Future<void> _loadSummary(ExchangeSession session) async {
    final result = await _getAccount(session);
    if (isClosed) return;
    add(switch (result) {
      Ok(:final value) => ExchangeSummaryLoaded(session, value),
      Err(:final failure) => ExchangeSummaryFailed(session, failure),
    });
  }

  Future<void> _loadAnnouncements(ExchangeSession session) async {
    final result = await _getAnnouncements(session);
    if (isClosed) return;
    add(switch (result) {
      Ok(:final value) => ExchangeAnnouncementsLoaded(session, value),
      Err(:final failure) => ExchangeAnnouncementsFailed(session, failure),
    });
  }

  Future<void> _stopRecurringBuy(ExchangeSession session) async {
    final result = await _stopDca(session);
    if (isClosed) return;
    add(switch (result) {
      Ok() => ExchangeDcaStopped(session),
      Err(:final failure) => ExchangeDcaStopFailed(session, failure),
    });
  }

  @override
  Future<void> close() async {
    await _access?.cancel();
    await _notifications?.cancel();
    return super.close();
  }
}
