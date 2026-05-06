import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:flutter/material.dart';

/// Yes / No row shown by `WizardScreen` in place of the dots + Next
/// button on the mission page. Tapping a button records consent +
/// advances; the currently-picked side stays highlighted so the user
/// can revisit (back gesture) and re-pick.
class MissionConsentRow extends StatelessWidget {
  const MissionConsentRow({
    super.key,
    required this.consent,
    required this.onYes,
    required this.onNo,
  });

  final bool? consent;
  final VoidCallback onYes;
  final VoidCallback onNo;

  @override
  Widget build(BuildContext context) {
    final hGap = Device.screen.width * 0.03;
    return Row(
      children: [
        Expanded(
          child: _ConsentButton(
            label: context.loc.wizardMissionYes,
            selected: consent == true,
            onTap: onYes,
          ),
        ),
        SizedBox(width: hGap),
        Expanded(
          child: _ConsentButton(
            label: context.loc.wizardMissionNo,
            selected: consent == false,
            onTap: onNo,
          ),
        ),
      ],
    );
  }
}

class _ConsentButton extends StatelessWidget {
  const _ConsentButton({
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
