import 'package:flutter/material.dart';

class SwapInProgressPage extends StatelessWidget {
  const SwapInProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Swap In Progress')),
      body: const Center(child: Text('Your swap is currently in progress.')),
    );
  }
}
