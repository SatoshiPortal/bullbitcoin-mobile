import 'package:bb_mobile/features/receive/ui/widgets/receive_network_selection.dart';
import 'package:bb_mobile/router.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ReceiveScaffold extends StatelessWidget {
  const ReceiveScaffold({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
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
            const ReceiveNetworkSelection(),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
