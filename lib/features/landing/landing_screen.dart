import 'package:bb_mobile/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Landing Screen'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                GoRouter.of(context).pushNamed(AppRoute.createWallet.name);
              },
              child: const Text('Create Wallet'),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                GoRouter.of(context).pushNamed(AppRoute.recoverWallet.name);
              },
              child: const Text('Recover Wallet'),
            ),
          ],
        ),
      ),
    );
  }
}
