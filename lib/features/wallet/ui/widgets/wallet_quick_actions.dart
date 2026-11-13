import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_quick_actions_usecase.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_ui/bull_ui.dart';

class WalletQuickActions extends StatelessWidget {
  const WalletQuickActions({
    super.key,
    required this.quickActions,
    required this.policy,
    required this.platformAllowsExchange,
    required this.onAction,
    required this.onCustomize,
  });

  final QuickActionsFacade quickActions;
  final WatchWalletQuickActionsUsecase policy;
  final bool Function(BuildContext) platformAllowsExchange;
  final void Function(BuildContext, QuickAction) onAction;
  final void Function(BuildContext, Set<QuickAction>, List<QuickAction>)
  onCustomize;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WalletQuickActionsPolicy>(
      stream: policy.watch(),
      initialData: policy.current,
      builder: (context, snapshot) {
        final current = snapshot.data ?? policy.current;
        final platformAllowed = platformAllowsExchange(context);
        return QuickActionsRow(
          facade: quickActions,
          available: current.available(platformAllowsExchange: platformAllowed),
          defaults: current.defaults,
          onAction: (action) {
            if (policy.current
                .available(platformAllowsExchange: platformAllowed)
                .contains(action)) {
              onAction(context, action);
            }
          },
          onCustomize: () {
            final latest = policy.current;
            onCustomize(
              context,
              latest.available(platformAllowsExchange: platformAllowed),
              latest.defaults,
            );
          },
        );
      },
    );
  }
}
