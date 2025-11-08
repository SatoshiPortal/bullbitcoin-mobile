import 'package:bb_mobile/core/screens/send_confirm_screen.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
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
    final bitcoinUnit = context.select(
      (TransferBloc bloc) => bloc.state.bitcoinUnit,
    );
    final formattedConfirmedAmountBitcoin =
        bitcoinUnit == BitcoinUnit.sats
            ? FormatAmount.sats(swap!.amountSat)
            : FormatAmount.btc(ConvertAmount.satsToBtc(swap!.amountSat));

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Transfer'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: FadingLinearProgress(
            height: 3,
            trigger: isConfirming,
            backgroundColor: context.colour.onPrimary,
            foregroundColor: context.colour.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Gap(24),
              CommonSendConfirmTopArea(
                formattedConfirmedAmountBitcoin:
                    formattedConfirmedAmountBitcoin,
                sendType: SendType.swap,
              ),
              const Gap(40),
              CommonChainSwapSendInfoSection(
                sendWalletLabel: fromWallet!.displayLabel,
                receiveWalletLabel: toWallet!.displayLabel,
                formattedBitcoinAmount: formattedConfirmedAmountBitcoin,
                swap: swap,
                absoluteFeesFormatted: absoluteFeesFormatted,
                absoluteFees: absoluteFees,
              ),
              const Spacer(),
              // const _Warning(),
              CommonConfirmSendErrorSection(
                confirmError: confirmError,
                buildError: null,
              ),

              CommonSendBottomButtons(
                isBitcoinWallet: !fromWallet.isLiquid,
                blocProviderValue: context.read<TransferBloc>(),
                onSendPressed: () {
                  context.read<TransferBloc>().add(
                    const TransferEvent.confirmed(),
                  );
                },
                disableSendButton: isConfirming,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
