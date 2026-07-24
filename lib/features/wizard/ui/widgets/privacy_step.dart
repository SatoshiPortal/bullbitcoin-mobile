import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/switch/bb_switch.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/wizard/ui/wizard_page.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/wizard_step_layout.dart';
import 'package:flutter/material.dart';

/// Privacy page body — a single opt-in switch card offering enhanced
/// Bitcoin privacy (compact block filter sync) for the default Bitcoin
/// wallet `CreateDefaultWalletsUsecase` is about to create. Purely
/// optional: leaving the switch off (or tapping Skip/Next without
/// touching it) keeps [WizardChoices.privateBitcoinSync] at its
/// `false` default and out of `touched`, so
/// `ApplyPendingWizardChoicesUsecase` never writes the preference and
/// any existing setting is left alone.
class PrivacyStep extends StatelessWidget {
  const PrivacyStep({
    super.key,
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final vGap = Device.screen.height * 0.02;
    return WizardStepLayout(
      page: WizardPage.privacy,
      title: loc.wizardPrivacyTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBText(
            loc.wizardPrivacyBody,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          SizedBox(height: vGap),
          _PrivacyToggleCard(enabled: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _PrivacyToggleCard extends StatelessWidget {
  const _PrivacyToggleCard({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final pad = Device.screen.width * 0.04;
    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: context.appColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // MergeSemantics + an explicit `toggled` flag so assistive tech
          // announces this row as a single switch control, and the whole
          // row — not just the small Switch hit target — toggles it.
          MergeSemantics(
            child: Semantics(
              toggled: enabled,
              child: InkWell(
                onTap: () => onChanged(!enabled),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: context.appColors.primary,
                    ),
                    SizedBox(width: pad * 0.5),
                    Expanded(
                      child: BBText(
                        loc.wizardPrivacyToggleTitle,
                        style: context.font.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.appColors.onSurface,
                        ),
                      ),
                    ),
                    BBSwitch(value: enabled, onChanged: onChanged),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: pad * 0.5),
          BBText(
            loc.wizardPrivacyToggleDescription,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
