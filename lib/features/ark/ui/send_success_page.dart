import 'package:bb_mobile/core/themes/app_theme.dart';
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
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Icon(Icons.check_circle, color: context.appColors.success, size: 72),
            const SizedBox(height: 24),
            const Text('Your Ark transaction was successful!'),
          ],
        ),
      ),
    );
  }
}
