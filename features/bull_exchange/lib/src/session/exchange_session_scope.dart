import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

import '../dashboard/exchange_home_screen.dart';
import '../recipients/recipients_scope.dart';
import 'exchange_cubit.dart';
import 'exchange_listener.dart';

/// Shares the foreground account across the mounted Exchange routes.
class ExchangeSessionScope extends StatelessWidget {
  final Exchange Function() exchange;
  final Preferences Function() preferences;
  final Widget child;

  const ExchangeSessionScope({
    required this.exchange,
    required this.preferences,
    required this.child,
    super.key,
  });

  static bool hasAccount(BuildContext context) =>
      context.read<ExchangeCubit>().state.hasUser;

  static bool watchHasAccount(BuildContext context) =>
      context.select((ExchangeCubit cubit) => cubit.state.hasUser);

  static Stream<bool> accountChanges(BuildContext context) {
    final cubit = context.read<ExchangeCubit>();
    return Stream<bool>.multi((controller) {
      controller.addSync(cubit.state.hasUser);
      final subscription = cubit.stream.listen(
        (state) => controller.addSync(state.hasUser),
        onDone: controller.closeSync,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  static ExchangeDashboardState watchDashboard(BuildContext context) =>
      context.select((ExchangeCubit cubit) {
        final state = cubit.state;
        return (
          summary: state.userSummary,
          displayBalances: state.displayBalances,
          summaryFailure: state.getUserSummaryFailure,
          stopDcaFailure: state.stopDcaFailure,
          announcements: state.announcements,
          unreadSupportMessages: state.unreadSupportMessages,
        );
      });

  static Future<void> refresh(BuildContext context) =>
      context.read<ExchangeCubit>().fetchUserSummary();

  static int watchUnreadSupportMessages(BuildContext context) => context.select(
    (ExchangeCubit cubit) => cubit.state.unreadSupportMessages,
  );

  static Future<void> markSupportMessagesRead(BuildContext context) =>
      context.read<ExchangeCubit>().markSupportMessagesRead();

  static Future<void> stopDca(BuildContext context) =>
      context.read<ExchangeCubit>().stopDca();

  static Future<void> reconnectNotifications(BuildContext context) =>
      context.read<ExchangeCubit>().reconnectWebSocket();

  static Future<Result<void, ExchangeFailure>> finishAuthentication(
    BuildContext context,
    Future<Result<void, ExchangeFailure>> Function({
      required bool Function() isCurrent,
    })
    authenticate, {
    required bool Function() isCurrent,
  }) => context.read<ExchangeCubit>().completeAuthentication(
    authenticate,
    isCurrent: isCurrent,
  );

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final capability = exchange();
      return ExchangeCubit(
        getAccount: capability.loadCurrentAccount,
        getAnnouncements: capability.loadCurrentAnnouncements,
        stopDca: () => capability.updateCurrentPreferences(dcaEnabled: false),
        currentAccess: () => capability.currentAccess,
        accessChanges: capability.watchAccess(),
        accountChanges: capability.watchAccountChanges(),
        reconnectNotifications: capability.reconnectCurrentNotifications,
        reconcileUnknownWrites: () async {
          final _ = await capability.reconcileUnknownWrites();
        },
      );
    },
    child: RecipientsScope(
      exchange: exchange,
      preferences: preferences,
      child: ExchangeListener(child: child),
    ),
  );
}
