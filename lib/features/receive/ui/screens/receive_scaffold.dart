import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_network_selection.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_payjoin_toggle_button.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ReceiveScaffold extends StatelessWidget {
  const ReceiveScaffold({super.key, required this.child, this.wallet});

  final Widget child;
  final Wallet? wallet;

  @override
  Widget build(BuildContext context) {
    // Only reserve the TopBar trailing slot for the payjoin toggle when it
    //  will actually render — Bitcoin receive with a payjoin-capable wallet —
    //  so the title stays centred on Liquid/Lightning and non-eligible
    //  wallets. Narrow selector: the scaffold only rebuilds on this bool.
    final showPayjoinToggle = context.select(
      (ReceiveBloc bloc) => bloc.state.isPayjoinToggleable,
    );
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      behavior: .translucent,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: TopBar(
            title: context.loc.receiveTitle,
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.goNamed(WalletRoute.walletHome.name);
              }
            },
            // Payjoin on/off toggle — only for Bitcoin receives with a
            //  payjoin-capable wallet; null (no trailing) otherwise so the
            //  title stays centred.
            action: showPayjoinToggle
                ? const ReceivePayjoinToggleButton()
                : null,
          ),
        ),
        body: Column(
          crossAxisAlignment: .stretch,
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
