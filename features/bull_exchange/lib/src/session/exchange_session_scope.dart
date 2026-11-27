import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

import '../account/domain/usecases/get_account_usecase.dart';
import '../dashboard/exchange_home_screen.dart';
import '../dca/domain/usecases/stop_dca_usecase.dart';
import '../recipients/recipients_scope.dart';
import '../support_chat/presentation/support_unread_bloc.dart';
import '../support_chat/domain/support_unread_state.dart';
import '../support_chat/domain/support_unread_event.dart';
import '../support_chat/domain/usecases/get_unread_support_count_usecase.dart';
import '../support_chat/domain/usecases/mark_support_messages_read_usecase.dart';
import 'domain/usecases/get_announcements_usecase.dart';
import 'domain/usecases/reconcile_unknown_writes_usecase.dart';
import 'exchange_bloc.dart';
import 'exchange_event.dart';
import 'exchange_listener.dart';
import 'exchange_state.dart';

/// Shares the foreground account across the mounted Exchange routes. The
/// scope owns its [ExchangeBloc] and provides it by value, so a rebuild of
/// the provider never closes it.
class ExchangeSessionScope extends StatefulWidget {
  final Exchange Function() exchange;
  final Preferences Function() preferences;
  final Widget child;

  const ExchangeSessionScope({
    required this.exchange,
    required this.preferences,
    required this.child,
    super.key,
  });

  /// Whether a session is signed in (its account may still be loading).
  static bool hasAccount(BuildContext context) =>
      context.read<ExchangeBloc>().state.session != null;

  static bool watchHasAccount(BuildContext context) =>
      context.select((ExchangeBloc bloc) => bloc.state.session != null);

  static ExchangeDashboardState watchDashboard(BuildContext context) =>
      context.select((ExchangeBloc bloc) => bloc.state);

  static Future<void> refresh(BuildContext context) async {
    context.read<ExchangeBloc>().add(const ExchangeRefreshRequested());
    context.read<SupportUnreadBloc>().add(const UnreadRecheckRequested());
  }

  /// The unread support messages the chat icon shows; zero hides it.
  static int watchUnreadSupportMessages(BuildContext context) => context.select(
    (SupportUnreadBloc bloc) => supportUnreadBadge(bloc.state),
  );

  /// The support chat showed its newest messages.
  static void markSupportMessagesRead(BuildContext context) =>
      context.read<SupportUnreadBloc>().add(const UnreadChatShown());

  static Future<void> stopDca(BuildContext context) async =>
      context.read<ExchangeBloc>().add(const ExchangeStopDcaRequested());

  /// Saves the WebView session as an API key. A stored key starts a new
  /// session, which loads its account by itself.
  static Future<Result<void, ExchangeFailure>> finishAuthentication(
    BuildContext context,
    Future<Result<void, ExchangeFailure>> Function({
      required bool Function() isCurrent,
    })
    authenticate, {
    required bool Function() isCurrent,
  }) => authenticate(isCurrent: isCurrent);

  @override
  State<ExchangeSessionScope> createState() => _ExchangeSessionScopeState();
}

class _ExchangeSessionScopeState extends State<ExchangeSessionScope> {
  late final Exchange _capability = widget.exchange();
  late final ExchangeBloc _bloc = ExchangeBloc(
    currentAccess: () => _capability.currentAccess,
    accessChanges: _capability.watchAccess(),
    accountChanges: _capability.watchAccountChanges(),
    getAccount: GetAccountUsecase(_capability),
    getAnnouncements: GetAnnouncementsUsecase(_capability),
    stopDca: StopDcaUsecase(_capability),
    reconcileUnknownWrites: ReconcileUnknownWritesUsecase(_capability),
  );

  late final SupportUnreadBloc _unread = SupportUnreadBloc(
    getUnreadCount: GetUnreadSupportCountUsecase(_capability),
    markRead: MarkSupportMessagesReadUsecase(_capability),
    currentAccess: () => _capability.currentAccess,
    accessChanges: _capability.watchAccess(),
    supportMessages: _capability.watchSupportMessages(),
  );

  @override
  void dispose() {
    unawaited(_bloc.close());
    unawaited(_unread.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider<ExchangeBloc>.value(value: _bloc),
      BlocProvider<SupportUnreadBloc>.value(value: _unread),
    ],
    child: RecipientsScope(
      exchange: widget.exchange,
      preferences: widget.preferences,
      child: ExchangeListener(
        onShow: () async {
          if (_bloc.state.session == null) return;
          await _capability.reconnectCurrentNotifications();
          // The reconnect covers pushes from now on; this covers whatever was
          // pushed while the app was hidden and the socket was down.
          _bloc.add(const ExchangeRefreshRequested());
          _unread.add(const UnreadRecheckRequested());
        },
        child: widget.child,
      ),
    ),
  );
}
