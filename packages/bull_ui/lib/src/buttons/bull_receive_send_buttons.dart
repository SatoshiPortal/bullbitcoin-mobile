import 'package:bull_ui/src/buttons/bull_button.dart';
import 'package:bull_ui/src/layout/gap.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The paired receive/send row pinned to the bottom of a wallet screen.
/// Labels and actions come from the caller so each feature keeps its own
/// routing out of here.
class BullReceiveSendButtons extends StatelessWidget {
  const BullReceiveSendButtons({
    super.key,
    required this.receiveLabel,
    required this.sendLabel,
    required this.onReceive,
    required this.onSend,
  });

  final String receiveLabel;
  final String sendLabel;
  final VoidCallback onReceive;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BullButton.secondary(
            iconData: Icons.arrow_downward,
            label: receiveLabel,
            iconFirst: true,
            onPressed: onReceive,
          ),
        ),
        const Gap(BullSpacing.xxs),
        Expanded(
          child: BullButton.secondary(
            iconData: Icons.crop_free,
            label: sendLabel,
            iconFirst: true,
            onPressed: onSend,
          ),
        ),
      ],
    );
  }
}
