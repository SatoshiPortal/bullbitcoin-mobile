import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/electrum_settings/presentation/bloc/electrum_settings_bloc.dart';
import 'package:bb_mobile/features/electrum_settings/ui/widgets/server_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DraggableServerList extends StatefulWidget {
  const DraggableServerList({
    super.key,
    required this.defaultServers,
    required this.customServers,
    required this.onCustomServerReordered,
    this.onAddCustomServer,
  });

  final List<ElectrumServer> defaultServers;
  final List<ElectrumServer> customServers;
  final Function(int oldIndex, int newIndex) onCustomServerReordered;
  final VoidCallback? onAddCustomServer;

  @override
  State<DraggableServerList> createState() => _DraggableServerListState();
}

class _DraggableServerListState extends State<DraggableServerList> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Default Servers'),
        const SizedBox(height: 8),
        ...widget.defaultServers.map(
          (server) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ServerListItem(
              server: server,
              onDelete: null, // Default servers can't be deleted
              onDragCompleted: () {
                context.read<ElectrumSettingsBloc>().add(
                  const SaveElectrumServerChanges(),
                );
              },
            ),
          ),
        ),
        if (widget.customServers.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionHeader(context, 'Custom Servers'),
          const SizedBox(height: 8),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIndex, newIndex) {
              widget.onCustomServerReordered(oldIndex, newIndex);
            },
            children: [
              for (final server in widget.customServers)
                Padding(
                  key: ValueKey(server.url),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ServerListItem(
                    server: server,
                    isDraggable: true,
                    onDelete:
                        () => _showDeleteConfirmationDialog(context, server),
                    onDragCompleted: () {
                      context.read<ElectrumSettingsBloc>().add(
                        const SaveElectrumServerChanges(),
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
        if (widget.onAddCustomServer != null) ...[
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: widget.onAddCustomServer,
            icon: Icon(Icons.add_circle_outline, color: context.colour.primary),
            label: BBText(
              'Add Custom Server',
              style: context.font.bodyMedium?.copyWith(
                color: context.colour.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showDeleteConfirmationDialog(
    BuildContext context,
    ElectrumServer server,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete Custom Server'),
            content: Text(
              'Are you sure you want to delete this server?\n\n${server.url}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: context.colour.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true && context.mounted) {
      context.read<ElectrumSettingsBloc>().add(
        DeleteCustomServer(server: server),
      );
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return BBText(
      title,
      style: context.font.titleSmall?.copyWith(
        color: context.colour.onSurface.withValues(alpha: 0.7),
      ),
    );
  }
}
