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
    if (widget.facade.initialized == false) return const SizedBox.shrink();
    final l10n = QuickActionsLocalizations.of(context);
    final layout = QuickActionsLayout.resolve(
      available: widget.available,
      defaults: widget.defaults,
      selection: widget.facade.selection,
    );
    final controls = <Widget>[
      for (final action in layout.primary)
        BullToolButton(
          label: action.label(l10n),
          icon: action.icon,
          onPressed: () => widget.onAction(action),
        ),
      if (layout.more.isNotEmpty)
        BullToolButton(
          label: l10n.more,
          icon: BullIcons.moreHoriz,
          onPressed: () => _showMore(context, layout.more),
        ),
    ];
    return Row(
      children: [
        for (var index = 0; index < controls.length; index++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == controls.length - 1 ? 0 : 8,
              ),
              child: controls[index],
            ),
          ),
      ],
    );
  }

  void _showMore(BuildContext context, List<QuickAction> actions) {
    final l10n = QuickActionsLocalizations.of(context);
    BullBottomSheet.show<void>(
      context: context,
      child: FractionallySizedBox(
        heightFactor: 0.8,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final action in actions)
                  BullSettingsEntryItem(
                    icon: action.icon,
                    title: action.label(l10n),
                    onTap: () {
                      Navigator.pop(context);
                      if (widget.available.contains(action)) {
                        widget.onAction(action);
                      }
                    },
                  ),
                BullSettingsEntryItem(
                  icon: BullIcons.tune,
                  title: l10n.customize,
                  onTap: () {
                    Navigator.pop(context);
                    widget.onCustomize();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
