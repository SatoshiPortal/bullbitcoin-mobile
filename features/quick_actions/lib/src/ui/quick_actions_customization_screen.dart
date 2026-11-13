import 'dart:async';

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

  Future<void> _apply(QuickActionSelection next) async {
    if (saving || identical(next, draft)) return;
    await _write(next);
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
                  : _editor(context, current),
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
    final editor = QuickActionsEditorLayout(
      selection: current,
      available: widget.available,
    );
    final items = editor.items;
    return ReorderableListView.builder(
      key: const ValueKey('quick-actions-list'),
      padding: const EdgeInsets.all(16),
      buildDefaultDragHandles: false,
      itemCount: items.length,
      header: _preview(context, current, editor),
      onReorderStart: (_) => unawaited(HapticFeedback.selectionClick()),
      onReorderItem: (from, to) {
        if (!saving) _apply(editor.move(from, to));
      },
      itemBuilder: (context, index) {
        final action = items[index];
        if (action == null) {
          return Semantics(
            key: const ValueKey('quick-actions-divider'),
            container: true,
            header: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(height: 1, color: context.bull.border),
                  const SizedBox(height: 12),
                  BullText(l10n.inMore, style: null),
                ],
              ),
            ),
          );
        }
        final name = action.label(l10n);
        final onHome = editor.home.contains(action);
        return ReorderableDelayedDragStartListener(
          key: ValueKey(action.id),
          index: index,
          enabled: !saving,
          child: Semantics(
            container: true,
            label: action.fullLabel(l10n),
            customSemanticsActions: {
              if (!saving && index > 0)
                CustomSemanticsAction(label: l10n.moveUp): () =>
                    _apply(editor.move(index, index - 1)),
              if (!saving && index < items.length - 1)
                CustomSemanticsAction(label: l10n.moveDown): () =>
                    _apply(editor.move(index, index + 1)),
              if (!saving && !onHome)
                CustomSemanticsAction(label: l10n.moveToHome): () =>
                    _apply(editor.moveToHome(action)),
              if (!saving && onHome)
                CustomSemanticsAction(label: l10n.moveToMore): () =>
                    _apply(editor.moveToMore(action)),
            },
            child: ExcludeSemantics(
              child: Container(
                key: ValueKey('quick-action-tile-${action.id}'),
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.bull.surface,
                  borderRadius: BorderRadius.circular(
                    context.bullShapes.button,
                  ),
                ),
                child: Row(
                  children: [
                    BullIcon(action.icon),
                    const SizedBox(width: 12),
                    Expanded(child: BullText(name, style: null)),
                    const SizedBox(width: 12),
                    const BullIcon(BullIcons.dragHandle),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _preview(
    BuildContext context,
    QuickActionSelection current,
    QuickActionsEditorLayout editor,
  ) {
    final l10n = QuickActionsLocalizations.of(context);
    final layout = QuickActionsLayout.resolve(
      available: widget.available,
      defaults: widget.defaults,
      selection: current,
    );
    final controls = <Widget>[
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
              for (var index = 0; index < controls.length; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(child: controls[index]),
              ],
            ],
          ),
        ),
        if (editor.home.isEmpty) BullText(l10n.emptyHint, style: null),
        const SizedBox(height: 16),
        BullText(l10n.dragHint, style: null),
        const SizedBox(height: 16),
        Semantics(header: true, child: BullText(l10n.onHome, style: null)),
        const SizedBox(height: 8),
      ],
    );
  }
}
