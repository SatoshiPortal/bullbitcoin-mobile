import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

class ExchangeAccountScreen extends StatelessWidget {
  const ExchangeAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.exchangeAccountTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: .center,
            children: [
              Icon(
                Icons.account_balance_wallet,
                size: 64,
                color: context.appColors.textMuted,
              ),
              const SizedBox(height: 16),
              Text(
                context.loc.exchangeAccountSettingsTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: .bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.loc.exchangeAccountComingSoon,
                style: TextStyle(fontSize: 16, color: context.appColors.textMuted),
                textAlign: .center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
