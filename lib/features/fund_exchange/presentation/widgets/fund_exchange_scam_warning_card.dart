import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart';

class FundExchangeScamWarningCard extends StatelessWidget {
  const FundExchangeScamWarningCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BullBorderedTile(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BullText(
              context.loc.fundExchangeWarningTacticsTitle,
              style: context.bullText.headlineSmall,
            ),
            const Gap(8.0),
            ..._scammerTacticsStrings(context).map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BullText('• ', style: context.bullText.bodyMedium),
                    Expanded(
                      child: BullText(item, style: context.bullText.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _scammerTacticsStrings(BuildContext context) => [
    context.loc.fundExchangeWarningTactic1,
    context.loc.fundExchangeWarningTactic2,
    context.loc.fundExchangeWarningTactic3,
    context.loc.fundExchangeWarningTactic4,
    context.loc.fundExchangeWarningTactic5,
    context.loc.fundExchangeWarningTactic6,
    context.loc.fundExchangeWarningTactic7,
    context.loc.fundExchangeWarningTactic8,
  ];
}
