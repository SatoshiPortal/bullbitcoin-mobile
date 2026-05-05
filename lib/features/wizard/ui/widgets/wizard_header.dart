import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';

/// Top bar shown above the wizard PageView: BULL logo on the left, Skip
/// action on the right.
class WizardHeader extends StatelessWidget {
  const WizardHeader({super.key, required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final hPad = Device.screen.width * 0.06;
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset(Assets.logos.bbLogoSmall.path, width: 32, height: 32),
          TextButton(
            onPressed: onSkip,
            child: Text(
              context.loc.wizardSkipButton,
              style: context.font.bodyLarge?.copyWith(
                color: context.appColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
