import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class FundExchangeDoneBottomNavigationBar extends StatelessWidget {
  const FundExchangeDoneBottomNavigationBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(BullSpacing.md),
        child: BullButton.secondary(
          label: context.loc.fundExchangeDoneButton,
          onPressed: () {
            context.goNamed(ExchangeRoute.exchangeHome.name);
          },
        ),
      ),
    );
  }
}
