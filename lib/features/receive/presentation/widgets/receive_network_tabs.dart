import 'package:flutter/material.dart';

class ReceiveNetworkTabs extends StatelessWidget {
  final Widget child;
  const ReceiveNetworkTabs({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [Text('Receive Network Tabs'), child],
    );
  }
}
