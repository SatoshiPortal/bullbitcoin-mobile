import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton;

/// Yes / No row shown by `WizardScreen` in place of the dots + Next
/// button on the mission page. Tapping a button records consent +
/// advances; the currently-picked side stays highlighted so the user
/// can revisit (back gesture) and re-pick. [yesFirst] puts Yes on the left;
/// the screen draws it at random so neither side favours an answer.
class MissionConsentRow extends StatelessWidget {
  const MissionConsentRow({
    super.key,
    required this.consent,
    required this.onYes,
    required this.onNo,
    required this.yesFirst,
  });

  final bool? consent;
  final VoidCallback onYes;
  final VoidCallback onNo;
  final bool yesFirst;

  @override
  Widget build(BuildContext context) {
    final hGap = Device.screen.width * 0.03;
    final yes = Expanded(
      child: _ConsentButton(
        label: context.loc.wizardMissionYes,
        selected: consent == true,
        onTap: onYes,
      ),
    );
    final no = Expanded(
      child: _ConsentButton(
        label: context.loc.wizardMissionNo,
        selected: consent == false,
        onTap: onNo,
      ),
    );
    return Row(
      children: [
        yesFirst ? yes : no,
        SizedBox(width: hGap),
        yesFirst ? no : yes,
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
    return BullButton.big(
      label: label,
      onPressed: onTap,
      bgColor: selected ? colors.primary : colors.surface,
      textColor: selected ? colors.onPrimary : colors.onSurface,
      borderColor: selected ? colors.primary : colors.border,
      outlined: !selected,
    );
  }
}
