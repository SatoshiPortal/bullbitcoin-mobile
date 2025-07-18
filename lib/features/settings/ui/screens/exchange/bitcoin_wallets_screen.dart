import 'package:flutter/material.dart';

class BitcoinWalletsScreen extends StatelessWidget {
  const BitcoinWalletsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Default Bitcoin Wallets')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.currency_bitcoin, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Default Bitcoin Wallets',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Default bitcoin wallet settings coming soon.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
