import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/view_models/electrum_server_view_model.dart';
import 'package:flutter/material.dart';

class ServerListItem extends StatelessWidget {
  const ServerListItem({
    super.key,
    required this.server,
    this.isDraggable = false,
    this.onDelete,
  });

  final ElectrumServerViewModel server;
  final bool isDraggable;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colour.surface.withValues(alpha: 180),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colour.outline, width: 1),
      ),
      child: Row(
        children: [
          if (isDraggable) ...[
            Icon(
              Icons.drag_handle,
              color: context.colour.onSurface.withValues(alpha: 128),
              size: 20,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  server.displayName,
                  style: context.font.bodyMedium?.copyWith(
                    color: context.colour.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                _buildStatusIndicator(context),
              ],
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: context.colour.error,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );

    return child;
  }

  Widget _buildStatusIndicator(BuildContext context) {
    final isOnline = server.status == ElectrumServerStatus.online;

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOnline ? Colors.green : Colors.amber,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isOnline ? 'Online' : 'Offline',
          style: context.font.bodySmall?.copyWith(
            color: context.colour.onSurface,
          ),
        ),
      ],
    );
  }
}
