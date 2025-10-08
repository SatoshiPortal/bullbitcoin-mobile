import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/widgets/add_custom_server_bottom_sheet.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/widgets/delete_custom_server_dialog.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/widgets/server_list_item.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/errors/electrum_servers_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    };
  }

  @override
  Widget build(BuildContext context) {
    final defaultServers = context.select(
      (ElectrumSettingsBloc bloc) => bloc.state.defaultServers,
    );
    final customServers = context.select(
      (ElectrumSettingsBloc bloc) => bloc.state.customServers,
    );
    final electrumServersError = context.select(
      (ElectrumSettingsBloc bloc) => bloc.state.electrumServersError,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (electrumServersError != null) ...[
          InfoCard(
            description: _getErrorMessage(electrumServersError),
            tagColor: context.colour.error,
            bgColor: context.colour.error.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          'Default Servers',
          style: context.font.titleSmall?.copyWith(
            color: context.colour.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        ...defaultServers.map(
          (server) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ServerListItem(server: server),
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
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () async {
            final newServerUrl = await AddCustomServerBottomSheet.show(context);
            if (newServerUrl != null && context.mounted) {
              context.read<ElectrumSettingsBloc>().add(
                ElectrumCustomServerAdded(url: newServerUrl),
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
