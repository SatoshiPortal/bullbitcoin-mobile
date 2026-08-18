import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class ExchangeLegacyTransactionsScreen extends StatelessWidget {
  const ExchangeLegacyTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BullPage(
      topBar: BullTopBar(
        title: context.loc.exchangeLegacyTransactionsTitle,
        onBack: () => context.pop(),
      ),
      child: Center(
        child: Text(context.loc.exchangeLegacyTransactionsComingSoon),
      ),
    );
  }
}
