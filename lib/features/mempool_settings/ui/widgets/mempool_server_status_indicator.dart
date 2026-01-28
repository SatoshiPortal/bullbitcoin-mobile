import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_status.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

class MempoolServerStatusIndicator extends StatelessWidget {
  final MempoolServerStatus status;

  const MempoolServerStatusIndicator({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String label;

    switch (status) {
      case MempoolServerStatus.online:
        icon = Icons.check_circle;
        color = context.appColors.success;
        label = context.loc.mempoolServerStatusOnline;
      case MempoolServerStatus.offline:
        icon = Icons.error;
        color = context.appColors.error;
        label = context.loc.mempoolServerStatusOffline;
      case MempoolServerStatus.checking:
        icon = Icons.sync;
        color = context.appColors.textMuted;
        label = context.loc.mempoolServerStatusChecking;
      case MempoolServerStatus.unknown:
        icon = Icons.help_outline;
        color = context.appColors.textMuted;
        label = context.loc.mempoolServerStatusUnknown;
    }

    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: context.font.bodySmall?.copyWith(
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }
}
