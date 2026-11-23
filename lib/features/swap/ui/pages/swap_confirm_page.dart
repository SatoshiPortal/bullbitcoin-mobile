import 'package:address_view/address_view.dart' show AddressViewer;
import 'package:fees/fees.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_confirmation_details.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/localization/onchain_send_labels_l10n.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/presentation/swap_failure_l10n.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_confirm_error.dart';
import 'package:fees_feature/fee_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullBottomSheet,
        BullButton,
        BullConfirmationHeader,
        BullFadingLinearProgress,
        BullOnchainSendInfoSection,
        BullText,
        BullTypographyX,
        Gap;

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
    final isConfirming = context.select(
      (TransferBloc bloc) => bloc.state.isConfirming,
    );
    final sendToExternal = context.select(
      (TransferBloc bloc) => bloc.state.sendToExternal,
    );
    final transferReady = context.select(
      (TransferBloc bloc) =>
          bloc.state.isSameChainTransfer || bloc.state.swap != null,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.swapConfirmTransferTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: BullFadingLinearProgress(
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
                BullConfirmationHeader(
                  amount: formattedConfirmedAmountBitcoin,
                  title: sendToExternal
                      ? context.loc.coreScreensExternalTransfer
                      : context.loc.coreScreensInternalTransfer,
                  icon: Image.asset(
                    Assets.icons.swap.path,
                    height: 24,
                    width: 24,
                  ),
                ),
                if (context.select(
                      (TransferBloc bloc) => bloc.state.confirmedConversion,
                    )
                    case final conversion?)
                  Text(
                    context.loc.amountEnteredAtRate(
                      conversion.enteredText,
                      conversion.currencyCode,
                      MaterialLocalizations.of(context).formatTimeOfDay(
                        TimeOfDay.fromDateTime(conversion.quotedAt.toLocal()),
                        alwaysUse24HourFormat: true,
                      ),
                    ),
                    style: context.bullType.label.copyWith(
                      color: context.appColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                const Gap(40),
                BlocSelector<TransferBloc, TransferState, bool>(
                  selector: (state) => state.isSameChainTransfer,
                  builder: (context, isSameChainTransfer) {
                    if (fromWallet == null) return const SizedBox.shrink();
                    if (isSameChainTransfer) {
                      final formattedFiatEquivalent = context.select((
                        TransferBloc bloc,
                      ) {
                        final amount = bloc.state.inputAmountSat;
                        final rate = bloc.state.exchangeRate;
                        final currency = bloc.state.fiatCurrencyCode ?? 'CAD';
                        if (rate == null) return '';
                        final fiatAmount = amount * rate / 100000000;
                        return '${fiatAmount.toStringAsFixed(2)} $currency';
                      });
                      final selectedFeeOption = context.select(
                        (TransferBloc bloc) => bloc.state.selectedFeeOption,
                      );
                      final customFee = context.select(
                        (TransferBloc bloc) => bloc.state.customFee,
                      );
                      final selectedFeeOptionTitle = feeSelectionRowLabel(
                        context,
                        ui: FeeUi.standard,
                        selection: selectedFeeOption,
                        customFee: customFee,
                        fastestLabel: context.loc.sendFastFee,
                      );
                      final toWalletLabel = context.select(
                        (TransferBloc bloc) =>
                            bloc.state.toWallet?.displayLabel(context) ?? '',
                      );
                      return BullOnchainSendInfoSection(
                        labels: context.loc.onchainSendLabels,
                        sendWalletLabel: fromWallet.displayLabel(context),
                        addressBuilder: (style, color) => AddressViewer(
                          toWalletLabel,
                          style: style,
                          color: color,
                        ),
                        formattedBitcoinAmount: formattedConfirmedAmountBitcoin,
                        formattedFiatEquivalent: formattedFiatEquivalent,
                        absoluteFees: absoluteFeesFormatted,
                        selectedFeeOptionTitle: selectedFeeOptionTitle,
                        onFeePriorityTap: () {
                          final bloc = context.read<TransferBloc>();
                          BullBottomSheet.show(
                            context: context,
                            child: FeeOptionsModal(
                              ui: FeeUi.standard,
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
                      if (swap == null) return const SizedBox.shrink();
                      final receiveWalletLabel = sendToExternal
                          ? null
                          : toWallet?.displayLabel(context);
                      return SwapConfirmationDetails(
                        sendWalletLabel: fromWallet.displayLabel(context),
                        receiveWalletLabel: receiveWalletLabel,
                        formattedBitcoinAmount: formattedConfirmedAmountBitcoin,
                        swap: swap,
                      );
                    }
                  },
                ),
                const Gap(24),
                _SwapConfirmationError(
                  errorMessage: transferConfirmErrorMessage(
                    buildTransactionException: buildTransactionException,
                    swapFailureMessage: swapFailure?.toTranslated(context),
                    buildFailureMessage: context.loc.sendErrorBuildFailed,
                    selectedCoinsUnavailableMessage:
                        context.loc.sendErrorSelectedCoinsUnavailable,
                    selectedCoinsInsufficientMessage:
                        context.loc.sendErrorSelectedCoinsInsufficient,
                    transactionChangedMessage:
                        context.loc.sendErrorTransactionChanged,
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
          child: BullButton.primary(
            label: context.loc.coreScreensConfirmButton,
            onPressed: isConfirming || fromWallet == null || !transferReady
                ? null
                : () => context.read<TransferBloc>().add(
                    const TransferEvent.confirmed(),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SwapConfirmationError extends StatelessWidget {
  const _SwapConfirmationError({required this.errorMessage});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    if (errorMessage case final message?) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            BullText(
              context.loc.sendErrorBuildFailed,
              style: context.bullType.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
              color: context.appColors.error,
              maxLines: 5,
              textAlign: .center,
            ),
            const Gap(8),
            BullText(
              message,
              style: context.bullType.body,
              color: context.appColors.error,
              maxLines: 5,
              textAlign: .center,
            ),
            const Gap(8),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
