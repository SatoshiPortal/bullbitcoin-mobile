import 'package:bb_mobile/features/utxos/interface_adapters/presenters/bloc/utxos_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UtxoDetailsScreen extends StatelessWidget {
  const UtxoDetailsScreen({super.key, required this.outpoint});

  final String outpoint;

  @override
  Widget build(BuildContext context) {
    final utxo = context.select(
      (UtxosBloc bloc) => bloc.state.getUtxo(outpoint),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('UTXO Details')),
      body: Center(
        child: Text(
          'Details for UTXO ${utxo?.address} in wallet ${utxo?.walletId}',
        ),
      ),
    );
  }
}
