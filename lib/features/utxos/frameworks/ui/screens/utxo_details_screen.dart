import 'package:flutter/material.dart';

class UtxoDetailsScreen extends StatelessWidget {
  final String walletId;
  final String utxoId;

  const UtxoDetailsScreen({
    super.key,
    required this.walletId,
    required this.utxoId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UTXO Details')),
      body: Center(child: Text('Details for UTXO $utxoId in wallet $walletId')),
    );
  }
}
