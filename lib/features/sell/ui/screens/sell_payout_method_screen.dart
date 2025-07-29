import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:flutter/material.dart';

class SellPayoutMethodScreen extends StatelessWidget {
  const SellPayoutMethodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Payout Method')),
      body: const SafeArea(child: ScrollableColumn(children: [])),
    );
  }
}
