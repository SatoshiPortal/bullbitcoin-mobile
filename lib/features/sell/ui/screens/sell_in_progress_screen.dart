import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullLoader, BullTypographyX;

class SellInProgressScreen extends StatelessWidget {
  const SellInProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return; // Don't allow back navigation
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.loc.sellTitle),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: .center,
              crossAxisAlignment: .center,
              children: [
                const Spacer(),
                Column(
                  children: [
                    const BullLoader.large(),
                    Text(
                      context.loc.sellInProgress,
                      style: context.bullType.subtitle
                          .copyWith(fontWeight: FontWeight.w700)
                          .copyWith(color: context.appColors.outlineVariant),
                    ),
                  ],
                ),
                const Spacer(),
                BullButton.secondary(
                  label: context.loc.sellGoHome,
                  onPressed: () {
                    context.goNamed(ExchangeRoute.exchangeHome.name);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
