import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
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

  String _getErrorMessage(ElectrumServersException error) {
    return switch (error) {
      LoadFailedException(reason: final r) =>
        'Failed to load servers${r != null ? ': $r' : ''}',
      SavePriorityFailedException(reason: final r) =>
        'Failed to save server priority${r != null ? ': $r' : ''}',
      AddFailedException(reason: final r) =>
        'Failed to add custom server${r != null ? ': $r' : ''}',
      DeleteFailedException(reason: final r) =>
        'Failed to delete custom server${r != null ? ': $r' : ''}',
      ElectrumServerAlreadyExistsException() => 'This server already exists',
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Default Servers',
          style: context.font.titleSmall?.copyWith(
            color: context.colour.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        if (customServers.isNotEmpty) ...[
          InfoCard(
            description:
                'To protect your privacy, default servers are not used when custom servers are configured.',
            tagColor: context.colour.onTertiary,
            bgColor: context.colour.tertiary.withValues(alpha: 0.1),
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
            'Custom Servers',
            style: context.font.titleSmall?.copyWith(
              color: context.colour.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '(Long press to drag and change priority)',
            style: context.font.bodySmall?.copyWith(
              color: context.colour.onSurface.withValues(alpha: 0.5),
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
            description: _getErrorMessage(electrumServersError),
            tagColor: context.colour.error,
            bgColor: context.colour.error.withValues(alpha: 0.1),
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
          icon: Icon(Icons.add_circle_outline, color: context.colour.primary),
          label: Text(
            'Add Custom Server',
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.primary,
            ),
          ),
        ),
      ],
    );
  }
}
