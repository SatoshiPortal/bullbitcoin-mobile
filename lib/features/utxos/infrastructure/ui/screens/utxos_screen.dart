import 'package:bb_mobile/features/utxos/frameworks/ui/routing/utxos_route.dart';
import 'package:bb_mobile/features/utxos/frameworks/ui/widgets/utxo_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UtxosScreen extends StatelessWidget {
  const UtxosScreen({super.key, required this.walletId});

  final String? walletId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UTXO List')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                UtxoCard(
                  isSpendable: true,
                  txId:
                      'ac029af1b9f62ab464ee0e5d290594fec0185b473d4fc3f07efa2337c390132f',
                  index: 0,
                  valueSat: 123456,
                  labels: const ['Label 1', 'Label 2'],
                  onTap: () {
                    context.pushNamed(
                      UtxosRoute.utxoDetails.name,
                      pathParameters: {
                        'walletId': walletId!,
                        'utxoId':
                            'ac029af1b9f62ab464ee0e5d290594fec0185b473d4fc3f07efa2337c390132f:0',
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
