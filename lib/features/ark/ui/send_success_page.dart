import 'package:bb_mobile/features/ark/router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SendSuccessPage extends StatelessWidget {
  const SendSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Successful'),
        actions: [
          CloseButton(
            onPressed: () {
              context.goNamed(ArkRoute.arkWalletDetail.name);
            },
          ),
        ],
      ),
      body: const Center(
        child: Column(
          children: [
            SizedBox(height: 24),
            Icon(Icons.check_circle, color: Colors.green, size: 72),
            SizedBox(height: 24),
            Text('Your Ark transaction was successful!'),
          ],
        ),
      ),
    );
  }
}
