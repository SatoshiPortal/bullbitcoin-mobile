import 'package:bull_ui/bull_ui.dart';

import '../../public/quick_actions_facade.dart';
import 'quick_action_presentation.dart';

class QuickActionsCustomizationScreen extends StatefulWidget {
  const QuickActionsCustomizationScreen({
    super.key,
    required this.facade,
    required this.available,
    required this.defaults,
  });

  final QuickActionsFacade facade;
  final Set<QuickAction> available;
  final List<QuickAction> defaults;

  @override
  State<QuickActionsCustomizationScreen> createState() =>
      _QuickActionsCustomizationScreenState();
}

class _QuickActionsCustomizationScreenState
    extends State<QuickActionsCustomizationScreen> {
  List<QuickAction>? draft;
  bool saving = false;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await widget.facade.load();
    if (mounted) {
      setState(() {
        draft = List.of(
          saved?.actions ?? widget.defaults.where(widget.available.contains),
        );
      });
    }
  }

  Future<void> _apply({required bool reset}) async {
    final current = draft;
    if (current == null || saving) return;
    setState(() {
      saving = true;
      failed = false;
    });
    final result = reset
        ? await widget.facade.reset()
        : await widget.facade.save(QuickActionSelection(current));
    if (mounted == false) return;
    switch (result) {
      case Ok():
        Navigator.pop(context);
      case Err():
        setState(() {
          saving = false;
          failed = true;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = QuickActionsLocalizations.of(context);
    final current = draft;
    return BullScaffold(
      body: SafeArea(
        child: Column(
          children: [
            BullTopBar(title: l10n.title, onBack: () => Navigator.pop(context)),
            Expanded(
              child: current == null
                  ? Center(child: BullText(l10n.loading, style: null))
                  : SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _editor(context, current),
                      ),
                    ),
            ),
            if (current != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (failed) ...[
                      BullText(l10n.saveFailed, style: null),
                      const SizedBox(height: 8),
                    ],
                    BullButton.big(
                      label: saving ? l10n.saving : l10n.save,
                      onPressed: () => _apply(reset: false),
                      disabled: saving,
                      bgColor: context.bull.primary,
                      textColor: context.bull.onPrimary,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _editor(BuildContext context, List<QuickAction> current) {
    final l10n = QuickActionsLocalizations.of(context);
    final layout = QuickActionsLayout.resolve(
      available: widget.available,
      defaults: widget.defaults,
      selection: QuickActionSelection(current),
    );
    final firstOverflow = current.indexWhere(
      (action) =>
          widget.available.contains(action) &&
          layout.primary.contains(action) == false,
    );
    final remainder = QuickAction.values.where(
      (action) =>
          widget.available.contains(action) &&
          current.contains(action) == false,
    );
    final preview = <Widget>[
      for (final action in layout.primary)
        BullQuickAction(
          label: action.label(l10n),
          icon: action.icon,
          onPressed: () {},
        ),
      if (layout.more.isNotEmpty)
        BullQuickAction(
          label: l10n.more,
          icon: BullIcons.moreHoriz,
          onPressed: () {},
          outlined: true,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BullText(l10n.preview, style: null),
        const SizedBox(height: 8),
        IgnorePointer(
          child: Row(
            children: [
              for (var index = 0; index < preview.length; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(child: preview[index]),
              ],
            ],
          ),
        ),
        if (current.isEmpty) BullText(l10n.emptyHint, style: null),
        const SizedBox(height: 16),
        BullText(l10n.maximumHint, style: null),
        const SizedBox(height: 16),
        BullText(l10n.onHome, style: null),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: current.length,
          onReorderItem: (oldIndex, newIndex) {
            if (saving) return;
            _move(current, oldIndex, newIndex);
          },
          itemBuilder: (context, index) {
            final action = current[index];
            final name = action.fullLabel(l10n);
            return Column(
              key: ValueKey(action.id),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (index == firstOverflow)
                  BullText(l10n.overflowHint, style: null),
                Row(
                  children: [
                    _iconControl(
                      tooltip: l10n.removeAction(name),
                      onPressed: saving
                          ? null
                          : () => setState(() => current.removeAt(index)),
                      icon: const BullIcon(BullIcons.removeCircleOutline),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BullText(name, style: null),
                          if (widget.available.contains(action) == false)
                            BullText(l10n.unavailable, style: null),
                        ],
                      ),
                    ),
                    _iconControl(
                      tooltip: '${l10n.moveUp}: $name',
                      onPressed: saving || index == 0
                          ? null
                          : () => _move(current, index, index - 1),
                      icon: const BullIcon(BullIcons.arrowUpward),
                    ),
                    _iconControl(
                      tooltip: '${l10n.moveDown}: $name',
                      onPressed: saving || index == current.length - 1
                          ? null
                          : () => _move(current, index, index + 1),
                      icon: const BullIcon(BullIcons.arrowDownward),
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      enabled: saving == false,
                      child: Semantics(
                        label: l10n.reorderAction(name),
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(child: BullIcon(BullIcons.dragHandle)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        BullText(l10n.inMore, style: null),
        for (final action in remainder)
          Row(
            children: [
              _iconControl(
                tooltip: l10n.addAction(action.fullLabel(l10n)),
                onPressed: saving
                    ? null
                    : () => setState(() => current.add(action)),
                icon: const BullIcon(BullIcons.addCircleOutline),
              ),
              Expanded(child: BullText(action.fullLabel(l10n), style: null)),
            ],
          ),
        const SizedBox(height: 16),
        BullButton.big(
          label: l10n.reset,
          onPressed: () => _apply(reset: true),
          disabled: saving,
          bgColor: context.bull.surface,
          textColor: context.bull.text,
          outlined: true,
        ),
      ],
    );
  }

  Widget _iconControl({
    required String tooltip,
    required VoidCallback? onPressed,
    required Widget icon,
  }) => SizedBox(
    width: 48,
    height: 48,
    child: IconButton(tooltip: tooltip, onPressed: onPressed, icon: icon),
  );

  void _move(List<QuickAction> actions, int from, int to) {
    if (to < 0 || to >= actions.length) return;
    setState(() {
      final action = actions.removeAt(from);
      actions.insert(to, action);
    });
  }
}
