import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/wizard/ui/wizard_page.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/background_activity_notice.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/wizard_step_layout.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show BullText;

/// Optional permissions page body. The page is the explanation: its Allow
/// button shows the OS prompt directly, without a second confirmation.
class PermissionsStep extends StatelessWidget {
  const PermissionsStep({super.key, this.page});

  /// Null outside the wizard, where no page indicator applies.
  final WizardPage? page;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final bodyStyle = context.font.bodyMedium?.copyWith(
      color: context.appColors.onSurfaceVariant,
      height: 1.4,
    );
    final vGapMd = Device.screen.height * 0.018;
    return WizardStepLayout(
      page: page,
      title: loc.settingsPermissionsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BullText(loc.permissionsIntro, style: bodyStyle),
          SizedBox(height: vGapMd),
          BullText(
            loc.permissionsNotificationsTitle,
            style: context.font.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.appColors.onSurface,
            ),
          ),
          SizedBox(height: vGapMd / 2),
          BullText(loc.permissionsNotificationsDescription, style: bodyStyle),
          SizedBox(height: vGapMd),
          BullText(loc.wizardPermissionsSettingsHint, style: bodyStyle),
          const BackgroundActivityNotice(),
        ],
      ),
    );
  }
}
