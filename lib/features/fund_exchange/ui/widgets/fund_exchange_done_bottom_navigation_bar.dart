import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:flutter/material.dart';

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
            Navigator.of(context, rootNavigator: true).pop();
          },
        ),
      ),
    );
  }
}
