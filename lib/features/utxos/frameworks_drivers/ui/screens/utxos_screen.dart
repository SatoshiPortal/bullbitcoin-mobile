import 'package:flutter/material.dart';

class UtxosScreen extends StatelessWidget {
  const UtxosScreen({super.key, required this.walletId});

  final String? walletId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UTXOs')),
      body: Center(child: Text('List of UTXOs for wallet $walletId')),
    );
  }
}
