import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';

class ServerListItem extends StatelessWidget {
  const ServerListItem({
    super.key,
    required this.server,
    this.isGrayed = false,
    this.onDragCompleted,
    this.isDraggable = false,
    this.onDelete,
  });

  final ElectrumServer server;
  final bool isGrayed;
  final VoidCallback? onDragCompleted;
  final bool isDraggable;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:
            isGrayed
                ? context.colour.surface.withValues(alpha: 180)
                : context.colour.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colour.outline, width: 1),
      ),
      child: Row(
        children: [
          if (isDraggable) ...[
            Icon(
              Icons.drag_handle,
              color: context.colour.onSurface.withValues(alpha: 128),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: BBText(
                        server.displayUrl,
                        style: context.font.bodyMedium?.copyWith(
                          color:
                              isGrayed
                                  ? context.colour.onSurface.withValues(
                                    alpha: 128,
                                  )
                                  : context.colour.onSurface,
                        ),
                      ),
                    ),
                    if (onDelete != null) ...[
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: context.colour.error,
                        ),
                        onPressed: onDelete,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                _buildStatusIndicator(context),
              ],
            ),
          ),
        ],
      ),
    );

    if (isDraggable) {
      return Draggable<ElectrumServer>(
        data: server,
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.7,
            child: SizedBox(
              width: MediaQuery.of(context).size.width - 32,
              child: child,
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: child),
        onDragCompleted: onDragCompleted,
        child: child,
      );
    }

    return child;
  }

  Widget _buildStatusIndicator(BuildContext context) {
    final isConnected = server.status == ElectrumServerStatus.online;

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isConnected ? Colors.green : Colors.amber,
          ),
        ),
        const SizedBox(width: 8),
        BBText(
          isConnected ? 'Connected' : 'Not Connected',
          style: context.font.bodySmall?.copyWith(
            color:
                isGrayed
                    ? context.colour.onSurface.withValues(alpha: 128)
                    : context.colour.onSurface,
          ),
        ),
        if (server.network == Network.bitcoinTestnet ||
            server.network == Network.liquidTestnet) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: context.colour.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: BBText(
              'TESTNET',
              style: context.font.labelSmall?.copyWith(
                color: context.colour.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
