import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart';

class WalletReceiveSyncNote extends StatelessWidget {
  final VoidCallback onSettings;
  const WalletReceiveSyncNote({super.key, required this.onSettings});
  @override
  Widget build(BuildContext context) => BullBorderedTile(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BullText(
          context.loc.syncReceiveNote,
          style: context.bullText.bodySmall,
        ),
        const Gap(BullSpacing.sm),
        Row(
          children: [
            BullButton.small(
              label: context.loc.syncSettingsAction,
              onPressed: onSettings,
              bgColor: context.bull.transparent,
              textColor: context.bull.primary,
              compact: true,
            ),
          ],
        ),
      ],
    ),
  );
}
