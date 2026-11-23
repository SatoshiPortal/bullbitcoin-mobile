import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bull_ui/app_theme.dart' show Device;
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullButtonSize;

/// Top bar shown above the wizard PageView: BULL logo on the left, Skip
/// action on the right.
class WizardHeader extends StatelessWidget {
  const WizardHeader({super.key, required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final hPad = Device.screen.width * 0.06;
    final vPad = Device.screen.height * 0.01;
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset(Assets.logos.bbLogoSmall.path, width: 32, height: 32),
          BullButton.secondary(
            label: context.loc.wizardSkipButton,
            onPressed: onSkip,
            compact: true,
            size: BullButtonSize.small,
          ),
        ],
      ),
    );
  }
}
