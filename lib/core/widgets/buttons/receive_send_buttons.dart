import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

/// The paired receive/send row pinned to the bottom of a wallet screen.
/// Labels and actions come from the caller so each feature keeps its own
/// routing out of here.
class ReceiveSendButtons extends StatelessWidget {
  const ReceiveSendButtons({
    super.key,
    required this.receiveLabel,
    required this.sendLabel,
    required this.onReceive,
    required this.onSend,
    this.sendDisabled = false,
  });

  final String receiveLabel;
  final String sendLabel;
  final VoidCallback onReceive;
  final VoidCallback onSend;
  final bool sendDisabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BBButton.big(
            iconData: Icons.arrow_downward,
            label: receiveLabel,
            iconFirst: true,
            onPressed: onReceive,
            bgColor: context.appColors.secondaryFixed,
            textColor: context.appColors.onSecondaryFixed,
            outlined: true,
            borderColor: context.appColors.onSecondaryFixed,
          ),
        ),
        const Gap(4),
        Expanded(
          child: BBButton.big(
            iconData: Icons.crop_free,
            label: sendLabel,
            iconFirst: true,
            onPressed: onSend,
            bgColor: context.appColors.secondaryFixed,
            textColor: context.appColors.onSecondaryFixed,
            outlined: true,
            borderColor: context.appColors.onSecondaryFixed,
            disabled: sendDisabled,
          ),
        ),
      ],
    );
  }
}
