import 'package:bull_ui/bull_ui.dart' show BullButton;
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

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
            context.goNamed(ExchangeRoute.exchangeHome.name);
          },
        ),
      ),
    );
  }
}
