import 'dart:async';

import 'package:bull_ui/bull_ui.dart';

import '../../public/quick_actions.dart';
import 'quick_action_presentation.dart';

class QuickActionsCustomizationScreen extends StatefulWidget {
  const QuickActionsCustomizationScreen({super.key, required this.cubit});

  final QuickActionsCubit cubit;

  @override
  State<QuickActionsCustomizationScreen> createState() =>
      _QuickActionsCustomizationScreenState();
}

class _QuickActionsCustomizationScreenState
    extends State<QuickActionsCustomizationScreen> {
  QuickActionSelection? get draft => widget.cubit.state.draft;
  bool get saving => widget.cubit.state.saving;
  late StreamSubscription<QuickActionsState> _subscription;
  int undoVersion = 0;

  @override
  void initState() {
    super.initState();
    _subscription = widget.cubit.stream.listen((_) {
      if (mounted) setState(() {});
    });
    widget.cubit.load();
  }

  @override
  void didUpdateWidget(QuickActionsCustomizationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cubit != widget.cubit) {
      _subscription.cancel();
      _subscription = widget.cubit.stream.listen((_) {
        if (mounted) setState(() {});
      });
      widget.cubit.load();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  /// The cubit holds the optimistic draft and restores it when a write fails.
  Future<bool> _write(QuickActionSelection? preference) async {
    final previous = draft;
    if (previous == null || saving) return false;
    final feedback = Overlay.of(context, rootOverlay: true);
    final failureMessage = QuickActionsLocalizations.of(context).saveFailed;
    undoVersion++;
    BullSnackBar.dismiss();
    final result = preference == null
        ? await widget.cubit.reset()
        : await widget.cubit.save(preference);
    switch (result) {
      case Ok():
        return true;
      case Err():
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
    final cubit = widget.cubit;
    final previous = cubit.state.selection;
    final feedback = Overlay.of(context, rootOverlay: true);
    final l10n = QuickActionsLocalizations.of(context);
    final restored = await _write(null);
    if (restored == false || feedback.mounted == false) return;
    final version = undoVersion;
    final revision = cubit.state.revision;
    BullSnackBar.showOnOverlay(
      feedback,
      message: l10n.defaultsRestored,
      actionLabel: l10n.undo,
      onAction: () async {
        if (version != undoVersion ||
            saving ||
            revision != cubit.state.revision) {
          return;
        }
        if (mounted) {
          await _write(previous);
        } else {
          final result = previous == null
              ? await cubit.reset()
              : await cubit.save(previous);
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
                    BullButton.secondary(
                      label: l10n.reset,
                      onPressed: (saving) ? null : _restoreDefaults,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The editable grid is the preview: the same tiles as Home and More.
  Widget _editor(BuildContext context, QuickActionSelection current) {
    final l10n = QuickActionsLocalizations.of(context);
    final editor = QuickActionsEditorLayout(
      selection: current,
      available: widget.cubit.state.available,
    );
    return SingleChildScrollView(
      key: const ValueKey('quick-actions-list'),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 8.0;
          final cell =
              (constraints.maxWidth -
                  spacing * (QuickActionsLayout.maximumCells - 1)) /
              QuickActionsLayout.maximumCells;
          Widget sized(Widget child) => SizedBox(width: cell, child: child);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BullText(l10n.dragHint, style: null),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: BullText(l10n.onHome, style: null),
              ),
              const SizedBox(height: 8),
              _zone(
                editor,
                onHome: true,
                child: Row(
                  children: [
                    for (
                      var slot = 0;
                      slot < QuickActionsLayout.maximumHomeActions;
                      slot++
                    ) ...[
                      sized(
                        slot < editor.home.length
                            ? _tile(context, editor, editor.home[slot], cell)
                            : _emptySlot(context),
                      ),
                      const SizedBox(width: spacing),
                    ],
                    sized(_moreTile(context, editor)),
                  ],
                ),
              ),
              if (editor.home.isEmpty) ...[
                const SizedBox(height: 8),
                BullText(l10n.emptyHint, style: null),
              ],
              Semantics(
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
              ),
              _zone(
                editor,
                onHome: false,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: BullQuickAction.height,
                  ),
                  child: Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (final action in editor.more)
                        sized(_tile(context, editor, action, cell)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Dropping on a zone outside any tile appends to that zone.
  Widget _zone(
    QuickActionsEditorLayout editor, {
    required bool onHome,
    required Widget child,
  }) => DragTarget<QuickAction>(
    onWillAcceptWithDetails: (_) => !saving,
    onAcceptWithDetails: (details) =>
        _apply(editor.dropAtEnd(details.data, onHome: onHome)),
    builder: (context, _, _) => child,
  );

  Widget _tile(
    BuildContext context,
    QuickActionsEditorLayout editor,
    QuickAction action,
    double width,
  ) {
    final l10n = QuickActionsLocalizations.of(context);
    final items = editor.items;
    final index = items.indexOf(action);
    final onHome = editor.home.contains(action);
    final face = _face(action.label(l10n), action.icon);
    return Semantics(
      key: ValueKey(action.id),
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
        child: DragTarget<QuickAction>(
          onWillAcceptWithDetails: (_) => !saving,
          onAcceptWithDetails: (details) =>
              _apply(editor.dropOn(details.data, action)),
          builder: (context, candidates, _) => LongPressDraggable<QuickAction>(
            key: ValueKey('quick-action-tile-${action.id}'),
            data: action,
            maxSimultaneousDrags: saving ? 0 : 1,
            feedback: SizedBox(
              key: const ValueKey('quick-action-drag-feedback'),
              width: width,
              child: _highlighted(context, face),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: face),
            child: candidates.any((candidate) => candidate != action)
                ? _highlighted(context, face)
                : face,
          ),
        ),
      ),
    );
  }

  /// Home's fixed More cell: never draggable; a drop on it moves to More.
  Widget _moreTile(BuildContext context, QuickActionsEditorLayout editor) {
    final l10n = QuickActionsLocalizations.of(context);
    final face = _face(l10n.more, BullIcons.moreHoriz, outlined: true);
    return Semantics(
      key: const ValueKey('quick-actions-more-tile'),
      container: true,
      label: l10n.more,
      child: ExcludeSemantics(
        child: DragTarget<QuickAction>(
          onWillAcceptWithDetails: (_) => !saving,
          onAcceptWithDetails: (details) =>
              _apply(editor.moveToMore(details.data)),
          builder: (context, candidates, _) =>
              candidates.isEmpty ? face : _highlighted(context, face),
        ),
      ),
    );
  }

  /// Taps are inert in the editor; only the long-press drag is live.
  Widget _face(String label, IconData icon, {bool outlined = false}) =>
      AbsorbPointer(
        child: BullQuickAction(
          label: label,
          icon: icon,
          outlined: outlined,
          onPressed: () {},
        ),
      );

  Widget _highlighted(BuildContext context, Widget child) => Container(
    foregroundDecoration: BoxDecoration(
      border: Border.all(color: context.bull.primary, width: 2),
      borderRadius: BorderRadius.circular(context.bullShapes.button),
    ),
    child: child,
  );

  Widget _emptySlot(BuildContext context) => Container(
    height: BullQuickAction.height,
    decoration: BoxDecoration(
      border: Border.all(color: context.bull.border),
      borderRadius: BorderRadius.circular(context.bullShapes.button),
    ),
  );
}
