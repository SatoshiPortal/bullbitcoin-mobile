import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

import '../dashboard/exchange_home_screen.dart';
import '../recipients/recipients_scope.dart';
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

  static Stream<bool> accountChanges(BuildContext context) {
    final bloc = context.read<ExchangeBloc>();
    return Stream<bool>.multi((controller) {
      controller.addSync(bloc.state.session != null);
      final subscription = bloc.stream.listen(
        (state) => controller.addSync(state.session != null),
        onDone: controller.closeSync,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  static ExchangeDashboardState watchDashboard(BuildContext context) =>
      context.select((ExchangeBloc bloc) => bloc.state);

  static Future<void> refresh(BuildContext context) async =>
      context.read<ExchangeBloc>().add(const ExchangeRefreshRequested());

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
    getAccount: _capability.loadAccount,
    getAnnouncements: _capability.loadAnnouncements,
    stopDca: (session) => _capability.updatePreferences(
      session,
      const ExchangePreferencesPatch(dcaEnabled: false),
    ),
    currentAccess: () => _capability.currentAccess,
    accessChanges: _capability.watchAccess(),
    accountChanges: _capability.watchAccountChanges(),
    reconcileUnknownWrites: () async {
      final _ = await _capability.reconcileUnknownWrites();
    },
  );

  @override
  void dispose() {
    unawaited(_bloc.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider<ExchangeBloc>.value(
    value: _bloc,
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
        },
        child: widget.child,
      ),
    ),
  );
}
