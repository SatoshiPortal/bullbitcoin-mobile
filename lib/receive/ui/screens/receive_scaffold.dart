import 'package:bb_mobile/_ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/receive/ui/widgets/receive_network_selection.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ReceiveScaffold extends StatelessWidget {
  const ReceiveScaffold({
    super.key,
    required this.child,
    required this.route,
  });

  final Widget child;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Receive',
          onBack: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed(AppRoute.home.name);
            }
          },
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(10),
          ReceiveNetworkSelection(selected: route),
          Expanded(child: child),
        ],
      ),
    );
  }
}
