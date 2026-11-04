import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FundExchangeDoneBottomNavigationBar extends StatelessWidget {
  const FundExchangeDoneBottomNavigationBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: BBButton.big(
          label: context.loc.fundExchangeDoneButton,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
          onPressed: () {
            context.goNamed(ExchangeRoute.exchangeHome.name);
          },
        ),
      ),
    );
  }
}
