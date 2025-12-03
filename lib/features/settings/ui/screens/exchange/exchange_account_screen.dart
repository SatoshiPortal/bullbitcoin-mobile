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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.account_balance_wallet,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                context.loc.exchangeAccountSettingsTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.loc.exchangeAccountComingSoon,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
