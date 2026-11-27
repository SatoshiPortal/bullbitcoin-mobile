import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../generated/l10n/views_localizations.dart';
import '../presentation/views_cubit.dart';
import '../presentation/views_state.dart';

/// The view in use, as a button that opens the list of the views this session
/// opened. It draws nothing when only one view is open.
final class ViewSwitcher extends StatelessWidget {
  const ViewSwitcher({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<ViewsCubit, ViewsState>(
    builder: (context, state) {
      if (state.views.length < 2) return const SizedBox.shrink();
      final l10n = ViewsLocalizations.of(context);
      final current = state.views
          .where((view) => view.id == state.active)
          .map((view) => view.name)
          .firstOrNull;
      return Semantics(
        button: true,
        label: l10n.viewSwitchTitle,
        value: current,
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: InkWell(
            onTap: () => _open(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      current ?? l10n.viewSwitchTitle,
                      overflow: TextOverflow.ellipsis,
                      style: context.bullType.body,
                    ),
                  ),
                  const Icon(Icons.expand_more),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Future<void> _open(BuildContext context) {
    final cubit = context.read<ViewsCubit>();
    return BullBottomSheet.show<void>(
      context: context,
      child: BlocProvider.value(value: cubit, child: const _SwitchSheet()),
    );
  }
}

final class _SwitchSheet extends StatelessWidget {
  const _SwitchSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = ViewsLocalizations.of(context);
    return BlocBuilder<ViewsCubit, ViewsState>(
      builder: (context, state) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              namesRoute: true,
              child: Text(l10n.viewSwitchTitle, style: context.bullType.title),
            ),
            const SizedBox(height: 12),
            for (final view in state.views)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  button: true,
                  selected: view.id == state.active,
                  label: l10n.viewSwitchTo(view.name),
                  excludeSemantics: true,
                  child: BullBorderedTile(
                    onTap: () async {
                      final navigator = Navigator.of(context);
                      await context.read<ViewsCubit>().activate(view.id);
                      navigator.pop();
                    },
                    child: Text(view.name, style: context.bullType.body),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
