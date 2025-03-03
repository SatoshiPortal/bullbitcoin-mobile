import 'package:bb_mobile/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/receive/ui/receive_router.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ReceiveAmountSegment extends StatelessWidget {
  const ReceiveAmountSegment({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Text('Receive Amount Segment'),
          FilledButton(
            onPressed: () {
              final state = context.read<ReceiveBloc>().state;
              final baseRoute =
                  state.paymentNetwork == ReceivePaymentNetwork.lightning
                      ? AppRoute.receiveLightning
                      : state.paymentNetwork == ReceivePaymentNetwork.liquid
                          ? AppRoute.receiveLiquid
                          : AppRoute.receiveBitcoin;
              context.replace(
                '${baseRoute.path}/${ReceiveSubroute.invoice.path}',
              );
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
