import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RecoverWalletSuccessScreen extends StatelessWidget {
  const RecoverWalletSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 100,
            ),
            const Text(
              'Wallet recovered successfully',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                context.pop();
              },
              child: const Text('Start using wallet'),
            ),
          ],
        ),
      ),
    );
  }
}
