import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/screens/send_confirm_screen.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/presentation/swap_failure_l10n.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_confirm_error.dart';
import 'package:bb_mobile/core/widgets/fees/fee_options_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

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

    final swapFailure = context.select(
      (TransferBloc bloc) => bloc.state.swapFailure,
    );
    final buildTransactionException = context.select(
      (TransferBloc bloc) => bloc.state.buildTransactionException,
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
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
                      final formattedFiatEquivalent = context.select((
                        TransferBloc bloc,
                      ) {
                        final amount = bloc.state.inputAmountSat;
                        final rate = bloc.state.exchangeRate ?? 0.0;
                        final currency = bloc.state.fiatCurrencyCode ?? 'CAD';
                        if (rate == 0.0) return '';
                        final fiatAmount = amount * rate / 100000000;
                        return '${fiatAmount.toStringAsFixed(2)} $currency';
                      });
                      final selectedFeeOptionTitle = context.select(
                        (TransferBloc bloc) =>
                            bloc.state.selectedFeeOption.title(),
                      );
                      final toWalletLabel = context.select(
                        (TransferBloc bloc) =>
                            bloc.state.toWallet?.displayLabel(context) ?? '',
                      );
                      return CommonOnchainSendInfoSection(
                        sendWalletLabel: fromWallet!.displayLabel(context),
                        receiveWalletLabel: toWalletLabel,
                        formattedBitcoinAmount: formattedConfirmedAmountBitcoin,
                        formattedFiatEquivalent: formattedFiatEquivalent,
                        absoluteFees: absoluteFeesFormatted,
                        selectedFeeOptionTitle: selectedFeeOptionTitle,
                        onFeePriorityTap: () {
                          final bloc = context.read<TransferBloc>();
                          BlurredBottomSheet.show(
                            context: context,
                            child: FeeOptionsModal(
                              viewState: bloc,
                              actions: bloc,
                              defaultAbsoluteCustomFee: true,
                              customFeeColors: FeeModalCustomFeeColors(
                                tile: context.appColors.onSecondary,
                                shadow: context.appColors.secondary,
                                unselectedIcon: context.appColors.surface,
                              ),
                            ),
                          ).then((selected) {
                            if (!context.mounted) return;
                            final bloc = context.read<TransferBloc>();
                            if (selected != null) {
                              // Preset picked — commit it. The
                              // event handler clears any in-flight
                              // arm from custom typing.
                              try {
                                final fee = FeeSelectionName.fromString(
                                  selected,
                                );
                                bloc.add(TransferEvent.feeOptionSelected(fee));
                              } catch (e) {
                                // Ignore invalid fee selection
                              }
                            } else {
                              // User dismissed the modal (tap
                              // outside, back, swipe). Finalize the
                              // typed custom rate if any. Replaces
                              // the old "Confirm Custom Fee" button.
                              bloc.add(
                                const TransferEvent.customFeeFinalized(),
                              );
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
                  errorMessage: transferConfirmErrorMessage(
                    buildTransactionException: buildTransactionException,
                    swapFailureMessage: swapFailure?.toTranslated(context),
                    buildFailureMessage: context.loc.sendErrorBuildFailed,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: CommonConfirmSendButton(
            disableSendButton: isConfirming,
            onPressed: () {
              context.read<TransferBloc>().add(const TransferEvent.confirmed());
            },
          ),
        ),
      ),
    );
  }
}
