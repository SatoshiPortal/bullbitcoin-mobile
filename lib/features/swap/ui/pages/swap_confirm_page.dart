import 'package:flutter/material.dart';

class SwapConfirmPage extends StatelessWidget {
  const SwapConfirmPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Swap')),
      body: const Center(child: Text('Please confirm your swap details.')),
    );
  }
}
