import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:secrets/storage.dart' show ViewSummary;

import '../../generated/l10n/views_localizations.dart';
import '../presentation/views_cubit.dart';
import '../presentation/views_state.dart';
import 'views_failure_l10n.dart';

/// The list of the views the session opened.
final class ViewsScreen extends StatelessWidget {
  final VoidCallback onBack;

  const ViewsScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final l10n = ViewsLocalizations.of(context);
    return BullScaffold(
      appBar: AppBar(
        backgroundColor: context.bull.background,
        foregroundColor: context.bull.onSurface,
        surfaceTintColor: context.bull.background,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: Semantics(
          header: true,
          child: Text(
            l10n.viewsTitle,
            style: TextStyle(color: context.bull.onSurface),
          ),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<ViewsCubit, ViewsState>(
          builder: (context, state) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.failure case final failure?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BullAlertCard(title: failure.toTranslated(context)),
                ),
              for (final view in state.views)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ViewTile(
                    view: view,
                    active: view.id == state.active,
                    busy: state.busy,
                  ),
                ),
              const SizedBox(height: 8),
              BullButton.primary(
                label: l10n.viewsAdd,
                onPressed: state.busy ? null : () => _askName(context),
              ),
              if (state.active != null) ...[
                const SizedBox(height: 24),
                _BackgroundBlock(
                  enabled: state.views
                      .where((view) => view.id == state.active)
                      .any((view) => view.backgroundEnabled),
                  busy: state.busy,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _askName(BuildContext context, {ViewSummary? rename}) async {
  final cubit = context.read<ViewsCubit>();
  final name = await BullBottomSheet.show<String>(
    context: context,
    avoidKeyboard: true,
    child: _NameSheet(initial: rename?.name ?? '', renaming: rename != null),
  );
  if (name == null) return;
  if (rename == null) {
    await cubit.create(name);
  } else {
    await cubit.rename(rename.id, name);
  }
}

final class _ViewTile extends StatelessWidget {
  final ViewSummary view;
  final bool active;
  final bool busy;

  const _ViewTile({
    required this.view,
    required this.active,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = ViewsLocalizations.of(context);
    final colors = context.bull;
    final cubit = context.read<ViewsCubit>();
    return Semantics(
      container: true,
      selected: active,
      child: BullBorderedTile(
        onTap: busy || active ? null : () => cubit.activate(view.id),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(view.name, style: context.bullType.body),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      BullBadge(
                        label: view.isProtected
                            ? l10n.viewProtected
                            : l10n.viewUnprotected,
                        background: colors.surfaceContainer,
                        foreground: colors.onSurface,
                      ),
                      if (active)
                        BullBadge(
                          label: l10n.viewActive,
                          background: colors.primary,
                          foreground: colors.onPrimary,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              key: ValueKey('view-rename-${view.id.value}'),
              tooltip: l10n.viewRename,
              icon: const Icon(Icons.edit_outlined),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: busy ? null : () => _askName(context, rename: view),
            ),
            IconButton(
              key: ValueKey('view-delete-${view.id.value}'),
              tooltip: l10n.viewDelete,
              icon: const Icon(Icons.delete_outline),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: busy || active ? null : () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<ViewsCubit>();
    final confirmed = await BullBottomSheet.show<bool>(
      context: context,
      child: _DeleteSheet(name: view.name),
    );
    if (confirmed == true) await cubit.delete(view.id);
  }
}

final class _BackgroundBlock extends StatelessWidget {
  final bool enabled;
  final bool busy;

  const _BackgroundBlock({required this.enabled, required this.busy});

  @override
  Widget build(BuildContext context) {
    final l10n = ViewsLocalizations.of(context);
    return MergeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.viewBackgroundTitle, style: context.bullType.body),
                const SizedBox(height: 4),
                Text(
                  l10n.viewBackgroundBody,
                  style: context.bullType.caption.copyWith(
                    color: context.bull.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          BullSwitch(
            value: enabled,
            onChanged: busy
                ? null
                : (value) => context.read<ViewsCubit>().setBackground(value),
          ),
        ],
      ),
    );
  }
}

final class _NameSheet extends StatefulWidget {
  final String initial;
  final bool renaming;

  const _NameSheet({required this.initial, required this.renaming});

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

final class _NameSheetState extends State<_NameSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ViewsLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            namesRoute: true,
            child: Text(
              widget.renaming ? l10n.viewRenameTitle : l10n.viewsAdd,
              style: context.bullType.title,
            ),
          ),
          const SizedBox(height: 16),
          BullLabeledTextInput(
            label: l10n.viewsNameLabel,
            value: _controller.text,
            controller: _controller,
            onChanged: (_) {},
          ),
          const SizedBox(height: 16),
          BullButton.primary(
            label: widget.renaming ? l10n.viewRename : l10n.viewsCreate,
            onPressed: () => Navigator.of(context).pop(_controller.text),
          ),
          const SizedBox(height: 8),
          BullButton.secondary(
            label: l10n.viewsCancel,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

final class _DeleteSheet extends StatelessWidget {
  final String name;

  const _DeleteSheet({required this.name});

  @override
  Widget build(BuildContext context) {
    final l10n = ViewsLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            namesRoute: true,
            child: Text(
              l10n.viewDeleteConfirm(name),
              style: context.bullType.body,
            ),
          ),
          const SizedBox(height: 16),
          BullButton.primary(
            label: l10n.viewDelete,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
          BullButton.secondary(
            label: l10n.viewsCancel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
