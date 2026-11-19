import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, Gap;
import 'package:material_ui/material_ui.dart';

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
    final colors = context.appColors;
    return Row(
      children: [
        Expanded(
          child: BullButton.big(
            iconData: Icons.arrow_downward,
            label: receiveLabel,
            iconFirst: true,
            onPressed: onReceive,
            bgColor: colors.actionButton,
            textColor: colors.onActionButton,
          ),
        ),
        const Gap(4),
        Expanded(
          child: BullButton.big(
            iconData: Icons.crop_free,
            label: sendLabel,
            iconFirst: true,
            onPressed: onSend,
            bgColor: colors.actionButton,
            textColor: colors.onActionButton,
            disabled: sendDisabled,
          ),
        ),
      ],
    );
  }
}
