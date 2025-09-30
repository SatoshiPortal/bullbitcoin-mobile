import 'package:bb_mobile/features/utxos/infrastructure/ui/routing/utxos_route.dart';
import 'package:bb_mobile/features/utxos/infrastructure/ui/widgets/utxo_card.dart';
import 'package:bb_mobile/features/utxos/interface_adapters/presenters/bloc/utxos_bloc.dart';
import 'package:bb_mobile/features/utxos/interface_adapters/presenters/view_models/utxo_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class UtxosScreen extends StatelessWidget {
  const UtxosScreen({super.key, required this.walletId});

  final String walletId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UTXO List')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh:
              () async => context.read<UtxosBloc>().add(UtxosLoaded(walletId)),
          child: BlocSelector<UtxosBloc, UtxosState, List<UtxoViewModel>>(
            selector: (state) => state.utxos,
            builder: (context, utxos) {
              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                itemCount: utxos.length,
                itemBuilder: (context, index) {
                  final utxo = utxos[index];
                  return UtxoCard(
                    isSpendable: utxo.isSpendable,
                    txId: utxo.txId,
                    index: utxo.index,
                    valueSat: utxo.valueSat,
                    labels: utxo.labels,
                    onTap: () {
                      context.pushNamed(
                        UtxosRoute.utxoDetails.name,
                        pathParameters: {
                          'walletId': utxo.walletId,
                          'outpoint': utxo.outpoint,
                        },
                        extra: context.read<UtxosBloc>(),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
