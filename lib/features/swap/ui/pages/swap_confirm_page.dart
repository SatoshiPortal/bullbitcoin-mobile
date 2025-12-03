import 'package:bb_mobile/core/screens/send_confirm_screen.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SwapConfirmPage extends StatelessWidget {
  const SwapConfirmPage({super.key});

  @override
  Widget build(BuildContext context) {
    final fromWallet = context.select(
      (TransferBloc bloc) => bloc.state.fromWallet,
    );
    final toWallet = context.select((TransferBloc bloc) => bloc.state.toWallet);
    final swap = context.select((TransferBloc bloc) => bloc.state.swap);
    final formattedInputAmount = context.select(
      (TransferBloc bloc) => bloc.state.formattedInputAmount,
    );
    final formattedConfirmedAmountBitcoin = formattedInputAmount;

    final confirmError = context.select(
      (TransferBloc bloc) => bloc.state.confirmTransactionException,
    );
    final absoluteFeesFormatted = context.select(
      (TransferBloc bloc) => bloc.state.absoluteFeesFormatted,
    );
    final absoluteFees = context.select(
      (TransferBloc bloc) => bloc.state.absoluteFees,
    );
    final isConfirming = context.select(
      (TransferBloc bloc) => bloc.state.isConfirming,
    );
    final sendToExternal = context.select(
      (TransferBloc bloc) => bloc.state.sendToExternal,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.swapConfirmTransferTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: FadingLinearProgress(
            height: 3,
            trigger: isConfirming,
            backgroundColor: context.appColors.onPrimary,
            foregroundColor: context.appColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: .stretch,
                    children: [
                      const Gap(8),
                      CommonSendConfirmTopArea(
                        formattedConfirmedAmountBitcoin:
                            formattedConfirmedAmountBitcoin,
                        sendType: SendType.swap,
                        sendToExternal: sendToExternal,
                      ),
                      const Gap(40),
                      CommonChainSwapSendInfoSection(
                        sendWalletLabel: fromWallet!.displayLabel,
                        receiveWalletLabel: toWallet!.displayLabel,
                        formattedBitcoinAmount: formattedConfirmedAmountBitcoin,
                        swap: swap!,
                        absoluteFeesFormatted: absoluteFeesFormatted,
                        absoluteFees: absoluteFees,
                      ),
                      const Gap(24),
                      CommonConfirmSendErrorSection(
                        confirmError: confirmError,
                        buildError: null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: CommonSendBottomButtons(
                isBitcoinWallet: !fromWallet.isLiquid,
                blocProviderValue: context.read<TransferBloc>(),
                onSendPressed: () {
                  context.read<TransferBloc>().add(
                    const TransferEvent.confirmed(),
                  );
                },
                disableSendButton: isConfirming,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
