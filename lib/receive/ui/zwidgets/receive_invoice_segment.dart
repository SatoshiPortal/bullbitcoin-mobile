import 'package:bb_mobile/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/receive/ui/receive_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ReceiveInvoiceSegment extends StatelessWidget {
  const ReceiveInvoiceSegment({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Text('Receive Invoice Segment'),
          ListTile(
            title: const Text('Amount'),
            trailing: const Icon(Icons.edit),
            onTap: () {
              final state = context.read<ReceiveBloc>().state;
              final baseRoute = state is LightningReceiveState
                  ? ReceiveRoute.receiveLightning
                  : state is LiquidReceiveState
                      ? ReceiveRoute.receiveLiquid
                      : ReceiveRoute.receiveBitcoin;
              context.replace(
                '${baseRoute.path}/${ReceiveRoute.amount.path}',
              );
            },
          ),
        ],
      ),
    );
  }
}
