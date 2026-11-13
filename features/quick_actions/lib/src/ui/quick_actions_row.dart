import 'package:bull_ui/bull_ui.dart';

import '../../public/quick_actions_facade.dart';
import 'quick_action_presentation.dart';

class QuickActionsRow extends StatefulWidget {
  const QuickActionsRow({
    super.key,
    required this.facade,
    required this.available,
    required this.defaults,
    required this.onAction,
    required this.onCustomize,
  });

  final QuickActionsFacade facade;
  final Set<QuickAction> available;
  final List<QuickAction> defaults;
  final ValueChanged<QuickAction> onAction;
  final VoidCallback onCustomize;

  @override
  State<QuickActionsRow> createState() => _QuickActionsRowState();
}

class _QuickActionsRowState extends State<QuickActionsRow> {
  @override
  void initState() {
    super.initState();
    widget.facade.addListener(_changed);
    widget.facade.load();
  }

  @override
  void didUpdateWidget(QuickActionsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.facade != widget.facade) {
      oldWidget.facade.removeListener(_changed);
      widget.facade.addListener(_changed);
      widget.facade.load();
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.facade.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = QuickActionsLocalizations.of(context);
    final loading = widget.facade.initialized == false;
    final layout = QuickActionsLayout.resolve(
      available: widget.available,
      defaults: widget.defaults,
      selection: widget.facade.selection,
    );
    final controls = <Widget>[
      for (final action in layout.primary)
        BullQuickAction(
          label: action.label(l10n),
          semanticLabel: action.fullLabel(l10n),
          icon: action.icon,
          disabled: loading,
          onPressed: () => widget.onAction(action),
          onLongPress: widget.onCustomize,
        ),
      if (layout.more.isNotEmpty)
        BullQuickAction(
          label: l10n.more,
          icon: BullIcons.moreHoriz,
          outlined: true,
          disabled: loading,
          onPressed: _showMore,
          onLongPress: widget.onCustomize,
        ),
    ];
    return SizedBox(
      height: BullQuickAction.height,
      child: Row(
        children: [
          for (var index = 0; index < controls.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            Expanded(child: controls[index]),
          ],
        ],
      ),
    );
  }

  Future<void> _showMore() async {
    final result = await BullBottomSheet.show<_MoreChoice>(
      context: context,
      child: _MoreSheet(
        facade: widget.facade,
        available: widget.available,
        defaults: widget.defaults,
      ),
    );
    if (!mounted || result == null) return;
    if (result.edit) {
      widget.onCustomize();
    } else if (result.action case final action?) {
      if (widget.available.contains(action)) widget.onAction(action);
    }
  }
}

class _MoreChoice {
  const _MoreChoice.action(this.action) : edit = false;
  const _MoreChoice.edit() : action = null, edit = true;
  final QuickAction? action;
  final bool edit;
}

/// The sheet owns its Navigator context, so closing it cannot pop WalletHome.
class _MoreSheet extends StatelessWidget {
  const _MoreSheet({
    required this.facade,
    required this.available,
    required this.defaults,
  });

  final QuickActionsFacade facade;
  final Set<QuickAction> available;
  final List<QuickAction> defaults;

  @override
  Widget build(BuildContext context) {
    final l10n = QuickActionsLocalizations.of(context);
    final actions = QuickActionsLayout.resolve(
      available: available,
      defaults: defaults,
      selection: facade.selection,
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: BullText(
                      l10n.more,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(context, const _MoreChoice.edit()),
                    child: BullText(l10n.edit, style: null),
                  ),
                  IconButton(
                    tooltip: l10n.close,
                    onPressed: () => Navigator.pop(context),
                    icon: const BullIcon(BullIcons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 24) / 4;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final action in actions)
                        SizedBox(
                          width: width,
                          child: BullQuickAction(
                            label: action.label(l10n),
                            semanticLabel: action.fullLabel(l10n),
                            icon: action.icon,
                            onPressed: () => Navigator.pop(
                              context,
                              _MoreChoice.action(action),
                            ),
                            onLongPress: () => Navigator.pop(
                              context,
                              const _MoreChoice.edit(),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
