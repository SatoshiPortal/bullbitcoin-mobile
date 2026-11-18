import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_status.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart' show BullTypographyX;

class MempoolServerStatusIndicator extends StatelessWidget {
  final MempoolServerStatus status;

  const MempoolServerStatusIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case MempoolServerStatus.online:
        color = context.appColors.success;
        label = context.loc.mempoolServerStatusOnline;
      case MempoolServerStatus.offline:
        color = context.appColors.warning;
        label = context.loc.mempoolServerStatusOffline;
      case MempoolServerStatus.checking:
        color = context.appColors.textMuted;
        label = context.loc.mempoolServerStatusChecking;
      case MempoolServerStatus.unknown:
        color = context.appColors.textMuted;
        label = context.loc.mempoolServerStatusUnknown;
    }

    // Same dot and label as the Electrum server rows, so both server
    // screens speak one status vocabulary.
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: .circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: context.bullType.label
              .copyWith(fontWeight: FontWeight.w400)
              .copyWith(color: context.appColors.onSurface),
        ),
      ],
    );
  }
}
