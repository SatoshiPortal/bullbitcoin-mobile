import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:flutter/material.dart';

class FundExchangeDoneBottomNavigationBar extends StatelessWidget {
  const FundExchangeDoneBottomNavigationBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: BBButton.big(
          label: 'Done',
          bgColor: theme.colorScheme.secondary,
          textColor: theme.colorScheme.onSecondary,
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
          },
        ),
      ),
    );
  }
}
