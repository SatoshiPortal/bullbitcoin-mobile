import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/support_unread_machine.dart';

/// Shell of [transitionSupportUnread]: applies events one at a time and
/// starts the read or the mark of the state it enters. Each answer carries
/// the session and attempt that started it.
class SupportUnreadBloc extends Bloc<SupportUnreadEvent, SupportUnreadState> {
  SupportUnreadBloc({
    required this._readCount,
    required this._markRead,
    required ExchangeAccess Function() currentAccess,
    required Stream<ExchangeAccess> accessChanges,
    required Stream<NotificationMessage> supportMessages,
  }) : super(const UnreadSignedOut()) {
    on<SupportUnreadEvent>(_onEvent, transformer: sequential());
    add(UnreadAccessChanged(currentAccess()));
    _access = accessChanges.listen((access) {
      if (!isClosed) add(UnreadAccessChanged(access));
    });
    _messages = supportMessages.listen((_) {
      if (!isClosed) add(const UnreadRecheckRequested());
    });
  }

  final Future<ExchangeRead<int>> Function(ExchangeSession) _readCount;
  final Future<ExchangeWrite<void>> Function(ExchangeSession) _markRead;
  StreamSubscription<ExchangeAccess>? _access;
  StreamSubscription<NotificationMessage>? _messages;

  void _onEvent(SupportUnreadEvent event, Emitter<SupportUnreadState> emit) {
    final previous = state;
    final next = transitionSupportUnread(previous, event);
    if (next == previous) return;
    emit(next);
    switch (next) {
      case UnreadReading(:final session, :final attempt) ||
          UnreadRefreshing(:final session, :final attempt):
        unawaited(_read(session, attempt));
      case UnreadMarking(:final session, :final attempt):
        unawaited(_mark(session, attempt));
      case UnreadSignedOut() ||
          UnreadUnavailable() ||
          UnreadKnown() ||
          UnreadStale():
        return;
    }
  }

  Future<void> _read(ExchangeSession session, int attempt) async {
    final read = await _readCount(session);
    if (!isClosed) add(UnreadCountAnswered(session, attempt, read));
  }

  Future<void> _mark(ExchangeSession session, int attempt) async {
    final write = await _markRead(session);
    if (!isClosed) add(UnreadMarkAnswered(session, attempt, write));
  }

  @override
  Future<void> close() async {
    await _access?.cancel();
    await _messages?.cancel();
    return super.close();
  }
}
