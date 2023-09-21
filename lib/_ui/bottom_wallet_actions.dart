import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeActionButtons extends StatelessWidget {
  const HomeActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    // final hasWallets = context.select((HomeCubit x) => x.state.hasWallets());

    // if (!hasWallets) return const SizedBox.shrink();

    final buttonWidth = (MediaQuery.of(context).size.width / 2) - 40;

    // const buttonWidth = double.maxFinite;
    //128.0;

    final color = context.colour.background;

    return Hero(
      tag: 'wallet-actions',
      child: Container(
        padding: const EdgeInsets.only(
          bottom: 16,
          top: 48,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color,
              color,
              color,
              color,
              color,
              color,
              color,
              color.withOpacity(0.9),
              color.withOpacity(0.5),
              color.withOpacity(0.0),
            ],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: buttonWidth,
              child: BBButton.smallRed(
                filled: true,
                onPressed: () async {
                  context.push('/send');
                  // final wallet = context.read<HomeCubit>().state.selectedWalletCubit!;

                  // await SendPage.SendPage.openSendPopUp(context, wallet);
                },
                label: 'Send',
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: buttonWidth,
              child: BBButton.smallRed(
                filled: true,
                onPressed: () async {
                  context.push('/receive');
                  // final wallet = context.read<HomeCubit>().state.selectedWalletCubit!;

                  // await ReceiveScreen.openPopUp(context, wallet);
                },
                label: 'Receive',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
