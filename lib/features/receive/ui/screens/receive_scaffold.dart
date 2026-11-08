import 'package:bb_mobile/features/receive/domain/usecases/poll_receive_wallet_usecase.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_polling.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_network_selection.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:go_router/go_router.dart';

class ReceiveScaffold extends StatelessWidget {
  const ReceiveScaffold({
    super.key,
    required this.child,
    required this.poll,
    this.wallet,
  });

  final Widget child;
  final Wallet? wallet;
  final PollReceiveWalletUsecase poll;

  @override
  Widget build(BuildContext context) {
    final target = context.select(
      (ReceiveBloc bloc) => (
        bloc.state.type == ReceiveType.lightning ? null : bloc.state.wallet?.id,
        bloc.state.wallet?.isLiquid ?? false,
      ),
    );
    return ReceivePolling(
      walletId: target.$1,
      isLiquid: target.$2,
      poll: poll,
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
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
