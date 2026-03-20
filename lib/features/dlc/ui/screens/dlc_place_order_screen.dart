import 'package:flutter/material.dart';

/// Stub screen for placing a new DLC option order.
/// Full implementation will wire up [PlaceDlcOrderUsecase] and key signing.
class DlcPlaceOrderScreen extends StatelessWidget {
  const DlcPlaceOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Place DLC Order')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Place Order — coming soon',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Will support call/put selection,\nstrike price, premium, quantity and expiry.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
