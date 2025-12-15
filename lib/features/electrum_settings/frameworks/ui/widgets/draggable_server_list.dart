import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/widgets/cards/info_card.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/widgets/add_custom_server_bottom_sheet.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/widgets/delete_custom_server_dialog.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/widgets/server_list_item.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/errors/electrum_servers_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class DraggableServerList extends StatelessWidget {
  const DraggableServerList({super.key});

  String _getErrorMessage(
    BuildContext context,
    ElectrumServersException error,
  ) {
    return switch (error) {
      LoadFailedException(reason: final r) => context.loc
          .electrumLoadFailedError(r != null ? ': $r' : ''),
      SavePriorityFailedException(reason: final r) => context.loc
          .electrumSavePriorityFailedError(r != null ? ': $r' : ''),
      AddFailedException(reason: final r) => context.loc.electrumAddFailedError(
        r != null ? ': $r' : '',
      ),
      DeleteFailedException(reason: final r) => context.loc
          .electrumDeleteFailedError(r != null ? ': $r' : ''),
      ElectrumServerAlreadyExistsException() =>
        context.loc.electrumServerAlreadyExists,
    };
  }

  @override
  Widget build(BuildContext context) {
    final defaultServers = context.select(
      (ElectrumSettingsBloc bloc) =>
          bloc.state.getServersSortedByPriority(isCustom: false),
    );
    final customServers = context.select(
      (ElectrumSettingsBloc bloc) =>
          bloc.state.getServersSortedByPriority(isCustom: true),
    );
    final electrumServersError = context.select(
      (ElectrumSettingsBloc bloc) => bloc.state.electrumServersError,
    );
    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(
          context.loc.electrumDefaultServers,
          style: context.font.titleSmall?.copyWith(
            color: context.appColors.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        if (customServers.isNotEmpty) ...[
          InfoCard(
            description: context.loc.electrumDefaultServersInfo,
            tagColor: context.appColors.tertiary,
            bgColor: context.appColors.tertiaryContainer,
          ),
          const SizedBox(height: 8),
        ],
        ...defaultServers.map(
          (server) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ServerListItem(
              server: server,
              disabled: customServers.isNotEmpty,
            ),
          ),
        ),
        if (customServers.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            context.loc.electrumCustomServers,
            style: context.font.titleSmall?.copyWith(
              color: context.appColors.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.loc.electrumDragToReorder,
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIndex, newIndex) {
              context.read<ElectrumSettingsBloc>().add(
                ElectrumCustomServersPrioritized(
                  movedFromListIndex: oldIndex,
                  movedToListIndex: newIndex,
                ),
              );
            },
            children: [
              for (final server in customServers)
                Padding(
                  key: ValueKey(server.url),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ServerListItem(
                    server: server,
                    isDraggable: true,
                    onDelete: () async {
                      final isConfirmed = await DeleteCustomServerDialog.show(
                        context,
                        server.url,
                        customServers.length == 1,
                      );
                      if (isConfirmed == true && context.mounted) {
                        context.read<ElectrumSettingsBloc>().add(
                          ElectrumCustomServerDeleted(server: server),
                        );
                      }
                    },
                  ),
                ),
            ],
          ),
        ],
        const Gap(16),
        if (electrumServersError != null) ...[
          InfoCard(
            description: _getErrorMessage(context, electrumServersError),
            tagColor: context.appColors.error,
            bgColor: context.appColors.errorContainer,
          ),
          const Gap(16),
        ],
        TextButton.icon(
          onPressed: () async {
            final result = await AddCustomServerBottomSheet.show(context);
            if (result != null && context.mounted) {
              context.read<ElectrumSettingsBloc>().add(
                ElectrumCustomServerAdded(
                  url: result.url,
                  enableSsl: result.enableSsl,
                ),
              );
            }
          },
          icon: Icon(
            Icons.add_circle_outline,
            color: context.appColors.primary,
          ),
          label: Text(
            context.loc.electrumAddCustomServer,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
