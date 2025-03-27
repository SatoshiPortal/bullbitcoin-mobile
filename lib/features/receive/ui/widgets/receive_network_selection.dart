import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:bb_mobile/ui/components/segment/segmented_full.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ReceiveNetworkSelection extends StatelessWidget {
  const ReceiveNetworkSelection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BBSegmentFull(
        items: const {
          'Bitcoin',
          'Lightning',
          'Liquid',
        },
        onSelected: (c) {
          if (c == 'Bitcoin') {
            context.goNamed(ReceiveRoute.receiveBitcoin.name);
          } else if (c == 'Lightning') {
            context.goNamed(ReceiveRoute.receiveLightning.name);
          } else if (c == 'Liquid') {
            context.goNamed(ReceiveRoute.receiveLiquid.name);
          }
        },
        initialValue: 'Lightning',
      ),
    );
  }
}
