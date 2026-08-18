import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart';

class FundExchangeRestrictedCard extends StatelessWidget {
  const FundExchangeRestrictedCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BullInfoCard(
      title: context.loc.fundExchangeRestrictedTitle,
      description: context.loc.fundExchangeRestrictedMessage,
      bgColor: context.bull.error.withValues(alpha: 0.1),
      tagColor: context.bull.error,
    );
  }
}
