import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton;

/// Allow / Not now, equally visible: notifications are optional.
class PermissionsChoiceRow extends StatelessWidget {
  const PermissionsChoiceRow({
    super.key,
    required this.busy,
    required this.onAllow,
    required this.onNotNow,
  });

  final bool busy;
  final VoidCallback onAllow;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hGap = Device.screen.width * 0.03;
    return Row(
      children: [
        Expanded(
          child: BullButton.big(
            label: context.loc.permissionsNotNow,
            onPressed: onNotNow,
            disabled: busy,
            bgColor: colors.surface,
            textColor: colors.onSurface,
            borderColor: colors.border,
            outlined: true,
          ),
        ),
        SizedBox(width: hGap),
        Expanded(
          child: BullButton.big(
            label: context.loc.permissionsAllowNotifications,
            onPressed: onAllow,
            disabled: busy,
            bgColor: colors.primary,
            textColor: colors.onPrimary,
          ),
        ),
      ],
    );
  }
}
