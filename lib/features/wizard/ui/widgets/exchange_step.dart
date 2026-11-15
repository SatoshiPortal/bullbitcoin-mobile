import 'package:flutter/widgets.dart' show MergeSemantics;
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/wizard/ui/wizard_page.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/wizard_step_layout.dart';
import 'package:bull_ui/bull_ui.dart';

class ExchangeStep extends StatelessWidget {
  const ExchangeStep({
    super.key,
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final bodyStyle = context.font.bodyMedium?.copyWith(
      color: context.appColors.onSurfaceVariant,
      height: 1.4,
    );
    final gap = Device.screen.height * 0.02;
    return WizardStepLayout(
      page: WizardPage.exchange,
      title: loc.wizardExchangeTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BullText(loc.wizardExchangeDescription, style: bodyStyle),
          SizedBox(height: gap),
          BullText(loc.wizardExchangeSupport, style: bodyStyle),
          SizedBox(height: gap),
          MergeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: BullText(loc.wizardExchangeToggle, style: bodyStyle),
                ),
                BullSwitch(value: enabled, onChanged: onChanged),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
