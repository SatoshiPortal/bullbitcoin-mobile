import 'package:flutter/material.dart';

class BuySuccessScreen extends StatelessWidget {
  const BuySuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buy Success')),
      body: const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center),
      ),
    );
  }
}
