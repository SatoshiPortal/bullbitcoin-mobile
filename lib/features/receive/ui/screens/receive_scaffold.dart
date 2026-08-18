import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_network_selection.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/widgets.dart';
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
      behavior: .translucent,
      child: BullPage(
        resizeToAvoidBottomInset: false,
        padding: EdgeInsets.zero,
        topBar: BullTopBar(
          title: context.loc.receiveTitle,
          onBack: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed(WalletRoute.walletHome.name);
            }
          },
        ),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            const Gap(BullSpacing.sm),
            ReceiveNetworkSelection(wallet: wallet),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
