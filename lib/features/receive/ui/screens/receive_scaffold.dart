import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_network_selection.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ReceiveScaffold extends StatelessWidget {
  const ReceiveScaffold({super.key, required this.child, this.wallet});

  final Widget child;
  final Wallet? wallet;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: TopBar(
            title: 'Receive',
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.goNamed(WalletRoute.walletHome.name);
              }
            },
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(10),
            ReceiveNetworkSelection(wallet: wallet),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
