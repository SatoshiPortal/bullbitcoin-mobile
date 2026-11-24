import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_ui/bull_ui.dart';

class WalletQuickActions extends StatelessWidget {
  const WalletQuickActions({
    super.key,
    required this.quickActions,
    required this.onAction,
    required this.onCustomize,
    required this.exchangePrompt,
    required this.onActivateExchange,
    this.unreadSupportMessages = 0,
  });
  final QuickActionsCubit quickActions;
  final void Function(BuildContext, QuickAction) onAction;
  final void Function(BuildContext) onCustomize;
  final ExchangePromptCubit exchangePrompt;
  final void Function(BuildContext) onActivateExchange;
  final int unreadSupportMessages;

  @override
  Widget build(BuildContext context) => QuickActionsRow(
    cubit: quickActions,
    onAction: (action) {
      if (quickActions.state.available.contains(action)) {
        onAction(context, action);
      }
    },
    onCustomize: () => onCustomize(context),
    exchangePrompt: exchangePrompt,
    onActivateExchange: () => onActivateExchange(context),
    unreadSupportMessages: unreadSupportMessages,
  );
}
