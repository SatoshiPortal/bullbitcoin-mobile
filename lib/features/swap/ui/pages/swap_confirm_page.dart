import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/screens/send_confirm_screen.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_fee_options_modal.dart';
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
                      BlocSelector<TransferBloc, TransferState, bool>(
                        selector: (state) => state.isSameChainTransfer,
                        builder: (context, isSameChainTransfer) {
                          if (isSameChainTransfer) {
                            final formattedFiatEquivalent = context.select(
                              (TransferBloc bloc) {
                                final amount = bloc.state.inputAmountSat;
                                final rate = bloc.state.exchangeRate ?? 0.0;
                                final currency = bloc.state.fiatCurrencyCode ?? 'CAD';
                                if (rate == 0.0) return '';
                                final fiatAmount = amount * rate / 100000000;
                                return '${fiatAmount.toStringAsFixed(2)} $currency';
                              },
                            );
                            final selectedFeeOptionTitle = context.select(
                              (TransferBloc bloc) => bloc.state.selectedFeeOption.title(),
                            );
                            final toWalletLabel = context.select(
                              (TransferBloc bloc) => bloc.state.toWallet?.displayLabel(context) ?? '',
                            );
                            return CommonOnchainSendInfoSection(
                              sendWalletLabel: fromWallet!.displayLabel(context),
                              receiveWalletLabel: toWalletLabel,
                              formattedBitcoinAmount: formattedConfirmedAmountBitcoin,
                              formattedFiatEquivalent: formattedFiatEquivalent,
                              absoluteFees: absoluteFeesFormatted,
                              selectedFeeOptionTitle: selectedFeeOptionTitle,
                              onFeePriorityTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: context.appColors.onSecondary,
                                  constraints: const BoxConstraints(maxWidth: double.infinity),
                                  useSafeArea: true,
                                  builder: (BuildContext buildContext) => BlocProvider.value(
                                    value: context.read<TransferBloc>(),
                                    child: const SwapFeeOptionsModal(),
                                  ),
                                ).then((selected) {
                                  if (selected != null && context.mounted) {
                                    try {
                                      final fee = FeeSelectionName.fromString(selected);
                                      context.read<TransferBloc>().add(
                                        TransferEvent.feeOptionSelected(fee),
                                      );
                                    } catch (e) {
                                      // Ignore invalid fee selection
                                    }
                                  }
                                });
                              },
                            );
                          } else {
                            final receiveWalletLabel = sendToExternal
                                ? null
                                : toWallet?.displayLabel(context);
                            return CommonChainSwapSendInfoSection(
                              sendWalletLabel: fromWallet!.displayLabel(context),
                              receiveWalletLabel: receiveWalletLabel,
                              formattedBitcoinAmount: formattedConfirmedAmountBitcoin,
                              swap: swap!,
                              absoluteFeesFormatted: absoluteFeesFormatted,
                              absoluteFees: absoluteFees,
                            );
                          }
                        },
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
                isBitcoinWallet: fromWallet != null && !fromWallet.isLiquid,
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
