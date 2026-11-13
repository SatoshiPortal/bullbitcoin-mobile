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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            BullText(
                              l10n.selectedCount(current.length),
                              style: null,
                            ),
                            for (final action in [
                              ...current,
                              ...QuickAction.values.where(
                                (action) =>
                                    current.contains(action) == false &&
                                    widget.available.contains(action),
                              ),
                            ])
                              _action(context, action, current),
                            if (failed) BullText(l10n.saveFailed, style: null),
                            const SizedBox(height: 16),
                            BullButton.big(
                              label: l10n.save,
                              onPressed: () => _apply(reset: false),
                              disabled: saving,
                              bgColor: context.bull.primary,
                              textColor: context.bull.onPrimary,
                            ),
                            const SizedBox(height: 8),
                            BullButton.big(
                              label: l10n.reset,
                              onPressed: () => _apply(reset: true),
                              disabled: saving,
                              bgColor: context.bull.surface,
                              textColor: context.bull.text,
                              outlined: true,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context,
    QuickAction action,
    List<QuickAction> current,
  ) {
    final l10n = QuickActionsLocalizations.of(context);
    final index = current.indexOf(action);
    final selected = index >= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BullSettingsEntryItem(
          icon: action.icon,
          title: action.label(l10n),
          subtitle: widget.available.contains(action) ? null : l10n.unavailable,
          trailing: BullCheckbox(
            checked: selected,
            onChanged: saving
                ? null
                : (checked) {
                    setState(() {
                      if (checked) {
                        current.add(action);
                      } else {
                        current.remove(action);
                      }
                    });
                  },
          ),
          onTap: saving
              ? null
              : () {
                  setState(() {
                    if (selected) {
                      current.remove(action);
                    } else {
                      current.add(action);
                    }
                  });
                },
        ),
        if (selected)
          Wrap(
            spacing: 8,
            children: [
              BullToolButton(
                label: "${l10n.moveUp}: ${action.label(l10n)}",
                icon: BullIcons.arrowUpward,
                disabled: saving || index == 0,
                onPressed: () => _move(current, index, index - 1),
              ),
              BullToolButton(
                label: "${l10n.moveDown}: ${action.label(l10n)}",
                icon: BullIcons.arrowDownward,
                disabled: saving || index == current.length - 1,
                onPressed: () => _move(current, index, index + 1),
              ),
            ],
          ),
      ],
    );
  }

  void _move(List<QuickAction> actions, int from, int to) {
    if (to < 0 || to >= actions.length) return;
    setState(() {
      final action = actions.removeAt(from);
      actions.insert(to, action);
    });
  }
}
