import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Landing Screen'),
          ElevatedButton(
            onPressed: () {
              GoRouter.of(context).go('/create-wallet');
            },
            child: const Text('Create Wallet'),
          ),
          TextButton(
            onPressed: () {
              GoRouter.of(context).go('/recover-wallet');
            },
            child: const Text('Recover Wallet'),
          ),
        ],
      ),
    );
  }
}
