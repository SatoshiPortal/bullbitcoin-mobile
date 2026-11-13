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
  QuickActionSelection? draft;
  bool saving = false;
  int undoVersion = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await widget.facade.load();
    if (mounted) {
      setState(() => draft = saved ?? QuickActionSelection(widget.defaults));
    }
  }

  /// Optimistic local presentation; the facade publishes only confirmed writes.
  Future<bool> _write(QuickActionSelection? preference) async {
    final previous = draft;
    if (previous == null || saving) return false;
    final feedback = Overlay.of(context, rootOverlay: true);
    final failureMessage = QuickActionsLocalizations.of(context).saveFailed;
    undoVersion++;
    BullSnackBar.dismiss();
    setState(() {
      draft = preference ?? QuickActionSelection(widget.defaults);
      saving = true;
    });
    final result = preference == null
        ? await widget.facade.reset()
        : await widget.facade.save(preference);
    switch (result) {
      case Ok():
        if (mounted) {
          setState(() => saving = false);
        } else {
          saving = false;
        }
        return true;
      case Err():
        if (mounted) {
          setState(() {
            draft = previous;
            saving = false;
          });
        } else {
          saving = false;
        }
        BullSnackBar.showOnOverlay(feedback, message: failureMessage);
        return false;
    }
  }

  Future<void> _editHome(List<QuickAction> home) async {
    final current = draft;
    if (current == null || saving) return;
    final _ = await _write(
      current.withHomeActions(available: widget.available, home: home),
    );
  }

  Future<void> _restoreDefaults() async {
    if (draft == null || saving) return;
    final facade = widget.facade;
    final previous = facade.selection;
    final feedback = Overlay.of(context, rootOverlay: true);
    final l10n = QuickActionsLocalizations.of(context);
    final restored = await _write(null);
    if (restored == false || feedback.mounted == false) return;
    final version = undoVersion;
    final revision = facade.revision;
    BullSnackBar.showOnOverlay(
      feedback,
      message: l10n.defaultsRestored,
      actionLabel: l10n.undo,
      onAction: () async {
        if (version != undoVersion || saving || revision != facade.revision) {
          return;
        }
        if (mounted) {
          await _write(previous);
        } else {
          final result = previous == null
              ? await facade.reset()
              : await facade.save(previous);
          if (result is Err<void, QuickActionsFailure>) {
            BullSnackBar.showOnOverlay(feedback, message: l10n.saveFailed);
          }
        }
      },
    );
  }

  List<QuickAction> _home(QuickActionSelection current) => current.actions
      .where(widget.available.contains)
      .take(QuickActionsLayout.maximumHomeActions)
      .toList();

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
                    SizedBox(
                      height: 24,
                      child: saving
                          ? Semantics(
                              liveRegion: true,
                              child: BullText(l10n.saving, style: null),
                            )
                          : const SizedBox.shrink(),
                    ),
                    BullButton.big(
                      label: l10n.reset,
                      onPressed: _restoreDefaults,
                      disabled: saving,
                      bgColor: context.bull.surface,
                      textColor: context.bull.text,
                      outlined: true,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _editor(BuildContext context, QuickActionSelection current) {
    final l10n = QuickActionsLocalizations.of(context);
    final home = _home(current);
    final layout = QuickActionsLayout.resolve(
      available: widget.available,
      defaults: widget.defaults,
      selection: current,
    );
    final remainder = QuickActionsLayout.moreOrder.where(
      (action) =>
          widget.available.contains(action) && home.contains(action) == false,
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
        if (home.isEmpty) BullText(l10n.emptyHint, style: null),
        const SizedBox(height: 16),
        BullText(l10n.maximumHint, style: null),
        const SizedBox(height: 16),
        BullText(l10n.onHome, style: null),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: home.length,
          onReorderItem: (oldIndex, newIndex) {
            if (saving == false) _move(home, oldIndex, newIndex);
          },
          itemBuilder: (context, index) {
            final action = home[index];
            final name = action.fullLabel(l10n);
            return Row(
              key: ValueKey(action.id),
              children: [
                _iconControl(
                  tooltip: l10n.removeAction(name),
                  onPressed: saving
                      ? null
                      : () => _editHome(List.of(home)..removeAt(index)),
                  icon: const BullIcon(BullIcons.removeCircleOutline),
                ),
                Expanded(child: BullText(name, style: null)),
                ReorderableDragStartListener(
                  index: index,
                  enabled: saving == false,
                  child: Semantics(
                    label: l10n.reorderAction(name),
                    customSemanticsActions: {
                      if (!saving && index > 0)
                        CustomSemanticsAction(
                          label: '${l10n.moveUp}: $name',
                        ): () =>
                            _move(home, index, index - 1),
                      if (!saving && index < home.length - 1)
                        CustomSemanticsAction(
                          label: '${l10n.moveDown}: $name',
                        ): () =>
                            _move(home, index, index + 1),
                    },
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(child: BullIcon(BullIcons.dragHandle)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        BullText(l10n.inMore, style: null),
        if (home.length == QuickActionsLayout.maximumHomeActions)
          BullText(l10n.homeFullHint, style: null),
        for (final action in remainder)
          Row(
            children: [
              _iconControl(
                tooltip: l10n.addAction(action.fullLabel(l10n)),
                onPressed:
                    saving ||
                        home.length == QuickActionsLayout.maximumHomeActions
                    ? null
                    : () => _editHome([...home, action]),
                icon: const BullIcon(BullIcons.addCircleOutline),
              ),
              Expanded(child: BullText(action.fullLabel(l10n), style: null)),
            ],
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

  Future<void> _move(List<QuickAction> home, int from, int to) async {
    if (saving || to < 0 || to >= home.length || from == to) return;
    final next = List.of(home);
    final action = next.removeAt(from);
    next.insert(to, action);
    await _editHome(next);
  }
}
