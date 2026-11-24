import 'dart:async';

import 'package:bull_ui/bull_ui.dart';

import '../../public/quick_actions.dart';
import 'quick_action_presentation.dart';

class QuickActionsRow extends StatefulWidget {
  const QuickActionsRow({
    super.key,
    required this.cubit,
    required this.onAction,
    required this.onCustomize,
    this.exchangePrompt,
    this.onActivateExchange,
    this.unreadSupportMessages = 0,
  });

  final QuickActionsCubit cubit;
  final ValueChanged<QuickAction> onAction;
  final VoidCallback onCustomize;

  /// Shows the exchange activation prompt in the More sheet while true.
  final ExchangePromptCubit? exchangePrompt;
  final VoidCallback? onActivateExchange;

  /// Shown on the support action, or on More while support sits behind it.
  final int unreadSupportMessages;

  @override
  State<QuickActionsRow> createState() => _QuickActionsRowState();
}

class _QuickActionsRowState extends State<QuickActionsRow> {
  late StreamSubscription<QuickActionsState> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.cubit.stream.listen((_) => _changed());
    widget.cubit.load();
  }

  @override
  void didUpdateWidget(QuickActionsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cubit != widget.cubit) {
      _subscription.cancel();
      _subscription = widget.cubit.stream.listen((_) => _changed());
      widget.cubit.load();
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = QuickActionsLocalizations.of(context);
    final loading = widget.cubit.state.initialized == false;
    final amounts = BullAmountScope.maybeOf(context)?.snapshot;
    final amountsHidden = amounts?.hideAmounts ?? true;
    final layout = QuickActionsLayout.resolve(
      available: widget.cubit.state.available,
      selection: widget.cubit.state.selection,
      defaults: widget.cubit.state.defaults,
    );
    final controls = <Widget>[
      for (final action in layout.primary)
        BullQuickAction(
          label: action.label(l10n, amountsHidden: amountsHidden),
          semanticLabel: action.fullLabel(l10n, amountsHidden: amountsHidden),
          icon: action.icon,
          disabled:
              loading ||
              (action == QuickAction.toggleAmounts && amounts?.isReady != true),
          badgeCount: action == QuickAction.support
              ? widget.unreadSupportMessages
              : 0,
          onPressed: () => widget.onAction(action),
          onLongPress: widget.onCustomize,
        ),
      if (layout.more.isNotEmpty)
        BullQuickAction(
          label: l10n.more,
          icon: BullIcons.moreHoriz,
          outlined: true,
          disabled: loading,
          badgeCount: layout.more.contains(QuickAction.support)
              ? widget.unreadSupportMessages
              : 0,
          onPressed: _showMore,
          onLongPress: widget.onCustomize,
        ),
    ];
    return BullQuickActionBar(children: controls);
  }

  Future<void> _showMore() async {
    final result = await BullBottomSheet.show<_MoreChoice>(
      context: context,
      child: _MoreSheet(
        cubit: widget.cubit,
        exchangePrompt: widget.exchangePrompt,
        unreadSupportMessages: widget.unreadSupportMessages,
      ),
    );
    if (!mounted || result == null) return;
    if (result.activateExchange) {
      widget.onActivateExchange?.call();
    } else if (result.edit) {
      widget.onCustomize();
    } else if (result.action case final action?) {
      if (widget.cubit.state.available.contains(action)) {
        widget.onAction(action);
      }
    }
  }
}

class _MoreChoice {
  const _MoreChoice.action(this.action)
    : edit = false,
      activateExchange = false;
  const _MoreChoice.edit()
    : action = null,
      edit = true,
      activateExchange = false;
  const _MoreChoice.activateExchange()
    : action = null,
      edit = false,
      activateExchange = true;
  final QuickAction? action;
  final bool edit;
  final bool activateExchange;
}

/// The sheet owns its Navigator context, so closing it cannot pop WalletHome.
class _MoreSheet extends StatelessWidget {
  const _MoreSheet({
    required this.cubit,
    this.exchangePrompt,
    this.unreadSupportMessages = 0,
  });

  final QuickActionsCubit cubit;
  final ExchangePromptCubit? exchangePrompt;
  final int unreadSupportMessages;

  @override
  Widget build(
    BuildContext context,
  ) => BullStreamValueBuilder<QuickActionsState>(
    stream: cubit.stream,
    initialValue: cubit.state,
    builder: (context, value) {
      final l10n = QuickActionsLocalizations.of(context);
      final amounts = BullAmountScope.maybeOf(context)?.snapshot;
      final amountsHidden = amounts?.hideAmounts ?? true;
      final actions = QuickActionsLayout.resolve(
        available: value.available,
        selection: value.selection,
        defaults: value.defaults,
      ).more;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.bull.border,
                      borderRadius: BorderRadius.circular(
                        context.bullShapes.badge,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: BullText(l10n.more, style: context.bullType.title),
                    ),
                    BullInlineTextButton(
                      onPressed: () =>
                          Navigator.pop(context, const _MoreChoice.edit()),
                      child: BullText(l10n.edit, style: context.bullType.label),
                    ),
                    BullInlineIconButton(
                      tooltip: l10n.close,
                      onPressed: () => Navigator.pop(context),
                      icon: const BullIcon(BullIcons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                BullQuickActionGrid(
                  children: [
                    for (final action in actions)
                      BullQuickAction(
                        label: action.label(l10n, amountsHidden: amountsHidden),
                        semanticLabel: action.fullLabel(
                          l10n,
                          amountsHidden: amountsHidden,
                        ),
                        icon: action.icon,
                        disabled:
                            action == QuickAction.toggleAmounts &&
                            amounts?.isReady != true,
                        badgeCount: action == QuickAction.support
                            ? unreadSupportMessages
                            : 0,
                        onPressed: () =>
                            Navigator.pop(context, _MoreChoice.action(action)),
                        onLongPress: () =>
                            Navigator.pop(context, const _MoreChoice.edit()),
                      ),
                  ],
                ),
                if (exchangePrompt case final prompt?)
                  BullStreamValueBuilder<bool>(
                    stream: prompt.stream,
                    initialValue: prompt.state,
                    builder: (context, visible) => visible
                        ? _ExchangePrompt(
                            onActivate: () => Navigator.pop(
                              context,
                              const _MoreChoice.activateExchange(),
                            ),
                            onDismiss: prompt.dismiss,
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _ExchangePrompt extends StatelessWidget {
  const _ExchangePrompt({required this.onActivate, required this.onDismiss});

  final VoidCallback onActivate;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = QuickActionsLocalizations.of(context);
    final colors = context.bull;
    return Padding(
      padding: const EdgeInsets.only(top: BullSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(context.bullShapes.card),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: BullSpacing.sm),
          child: Row(
            children: [
              BullIcon(
                BullIcons.candlestickChart,
                size: 20,
                color: colors.textMuted,
              ),
              const SizedBox(width: BullSpacing.xs),
              Expanded(
                child: BullText(
                  l10n.exchangeOff,
                  style: context.bullType.body,
                  color: colors.textMuted,
                ),
              ),
              BullInlineTextButton(
                onPressed: onActivate,
                child: BullText(
                  l10n.activate,
                  style: context.bullType.label.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  color: colors.primary,
                ),
              ),
              BullInlineIconButton(
                tooltip: l10n.dismiss,
                onPressed: onDismiss,
                icon: const BullIcon(BullIcons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
