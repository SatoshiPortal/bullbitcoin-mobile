import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton;
import 'package:bull_exchange/bull_exchange.dart';
import 'package:material_ui/material_ui.dart';

class FundExchangeDoneBottomNavigationBar extends StatelessWidget {
  const FundExchangeDoneBottomNavigationBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: BullButton.secondary(
          label: context.loc.fundExchangeDoneButton,
          onPressed: () {
            BullExchangeNavigation.goToDashboard(context);
          },
        ),
      ),
    );
  }
}
