import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/wizard_step_layout.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class MissionStep extends StatelessWidget {
  const MissionStep({
    super.key,
    required this.stepIndex,
    required this.totalSteps,
    required this.consent,
    required this.onChanged,
  });

  final int stepIndex;
  final int totalSteps;
  // `null` until the user explicitly taps Yes or No.
  final bool? consent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final bodyStyle = context.font.bodyMedium?.copyWith(
      color: context.appColors.onSurfaceVariant,
      height: 1.4,
    );
    return WizardStepLayout(
      stepIndex: stepIndex,
      totalSteps: totalSteps,
      title: loc.wizardMissionTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.wizardMissionBody1, style: bodyStyle),
          const Gap(12),
          Text(loc.wizardMissionBody2, style: bodyStyle),
          const Gap(20),
          Text(
            loc.wizardMissionQuestion,
            style: context.font.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.appColors.onSurface,
            ),
          ),
          const Gap(12),
          Row(
            children: [
              Expanded(
                child: _ChoiceButton(
                  label: loc.wizardMissionYes,
                  selected: consent == true,
                  onTap: () => onChanged(true),
                ),
              ),
              const Gap(12),
              Expanded(
                child: _ChoiceButton(
                  label: loc.wizardMissionNo,
                  selected: consent == false,
                  onTap: () => onChanged(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return BBButton.big(
      label: label,
      onPressed: onTap,
      bgColor: selected ? colors.primary : colors.surface,
      textColor: selected ? colors.onPrimary : colors.onSurface,
      borderColor: selected ? colors.primary : colors.border,
      outlined: !selected,
    );
  }
}
