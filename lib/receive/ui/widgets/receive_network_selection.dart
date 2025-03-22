import 'package:bb_mobile/_ui/components/segment/segmented_full.dart';
import 'package:bb_mobile/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/receive/ui/receive_router.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ReceiveNetworkSelection extends StatelessWidget {
  const ReceiveNetworkSelection({super.key});

  @override
  Widget build(BuildContext context) {
    final network = context.select(
      (ReceiveBloc bloc) => bloc.state is BitcoinReceiveState
          ? 'Bitcoin'
          : bloc.state is LiquidReceiveState
              ? 'Liquid'
              : 'Lightning',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BBSegmentFull<String>(
        items: const {
          'Bitcoin',
          'Lightning',
          'Liquid',
        },
        onSelected: (c) {
          if (c == 'Bitcoin') {
            context.goNamed(AppRoute.receiveBitcoin.name);
          } else if (c == 'Lightning') {
            context.goNamed(AppRoute.receiveLightning.name);
          } else if (c == 'Liquid') {
            context.goNamed(AppRoute.receiveLiquid.name);
          }
        },
        selected: network,
      ),
    );
  }
}
