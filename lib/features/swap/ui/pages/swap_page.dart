import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_amount_input.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_balance_row.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_external_address_input.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_from_wallet_dropdown.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_to_wallet_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SwapPage extends StatefulWidget {
  const SwapPage({super.key});
  @override
  _SwapPageState createState() => _SwapPageState();
}

class _SwapPageState extends State<SwapPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  int _amountSat = 0;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<TransferBloc>();
    final bitcoinUnit = bloc.state.bitcoinUnit;
    final initialAmount = bloc.state.amount;
    if (initialAmount.isNotEmpty) {
      _amountController.text = initialAmount;
    }
    _amountController.addListener(() {
      // Keep the amount in satoshis updated so we can use it elsewhere to
      // calculate fees etc. in Stateless child Widgets like SwapAmountInput
      // and SwapFeesRow.
      setState(() {
        _amountSat = bitcoinUnit == BitcoinUnit.sats
            ? int.tryParse(_amountController.text) ?? 0
            : ConvertAmount.btcToSats(
                double.tryParse(_amountController.text) ?? 0,
              );
      });
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TransferBloc, TransferState>(
      listenWhen: (previous, current) => previous.amount != current.amount,
      listener: (context, state) {
        if (state.amount != _amountController.text) {
          _amountController.text = state.amount;
          final bitcoinUnit = state.bitcoinUnit;
          setState(() {
            _amountSat = bitcoinUnit == BitcoinUnit.sats
                ? int.tryParse(state.amount) ?? 0
                : ConvertAmount.btcToSats(double.tryParse(state.amount) ?? 0);
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.loc.swapTransferTitle),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: BlocSelector<TransferBloc, TransferState, bool>(
              selector: (state) => state.isStarting || state.isCreatingSwap,
              builder: (context, isLoading) => FadingLinearProgress(
                height: 3,
                trigger: isLoading,
                backgroundColor: context.appColors.onPrimary,
                foregroundColor: context.appColors.primary,
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Gap(12),
                  InfoCard(
                    description: context.loc.swapInfoDescription,
                    tagColor: context.appColors.inverseSurface,
                    bgColor: context.appColors.inverseSurface.withValues(
                      alpha: 0.1,
                    ),
                  ),
                  const Gap(12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      BlocSelector<TransferBloc, TransferState, bool>(
                        selector: (state) => state.sendToExternal,
                        builder: (context, sendToExternal) {
                          return Text(
                            sendToExternal
                                ? context.loc.swapExternalTransferLabel
                                : context.loc.swapInternalTransferTitle,
                            style: context.font.bodyLarge,
                          );
                        },
                      ),
                      BlocSelector<TransferBloc, TransferState, bool>(
                        selector: (state) => state.sendToExternal,
                        builder: (context, sendToExternal) {
                          return Switch(
                            value: sendToExternal,
                            activeThumbColor: context.appColors.onSecondary,
                            activeTrackColor: context.appColors.secondary,
                            inactiveThumbColor: context.appColors.onSecondary,
                            inactiveTrackColor: context.appColors.surface,
                            trackOutlineColor:
                                WidgetStateProperty.resolveWith<Color?>(
                                  (Set<WidgetState> states) =>
                                      Colors.transparent,
                                ),
                            onChanged: (value) {
                              context.read<TransferBloc>().add(
                                TransferEvent.sendToExternalToggled(value),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const Gap(12),
                  const SwapFromWalletDropdown(),
                  const Gap(12),
                  BlocSelector<TransferBloc, TransferState, bool>(
                    selector: (state) => state.sendToExternal,
                    builder: (context, sendToExternal) {
                      if (sendToExternal) {
                        return const SwapExternalAddressInput();
                      } else {
                        return const SwapToWalletDropdown();
                      }
                    },
                  ),
                  const Gap(12),
                  SwapAmountInput(
                    amountController: _amountController,
                    amountSat: _amountSat,
                  ),
                  const Gap(12),
                  SwapBalanceRow(amountController: _amountController),
                  const Gap(12),
                  BlocSelector<
                    TransferBloc,
                    TransferState,
                    SwapCreationException?
                  >(
                    selector: (state) => state.swapCreationException,
                    builder: (context, swapCreationError) {
                      if (swapCreationError == null) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        swapCreationError.message,
                        style: context.font.labelLarge?.copyWith(
                          color: context.appColors.error,
                        ),
                        maxLines: 4,
                      );
                    },
                  ),
                  const Gap(24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      BlocSelector<TransferBloc, TransferState, bool>(
                        selector: (state) => state.receiveExactAmount,
                        builder: (context, receiveExactAmount) {
                          return Text(
                            receiveExactAmount
                                ? context.loc.swapReceiveExactAmountLabel
                                : context.loc.swapSubtractFeesLabel,
                            style: context.font.bodyLarge,
                          );
                        },
                      ),
                      BlocSelector<TransferBloc, TransferState, bool>(
                        selector: (state) => state.receiveExactAmount,
                        builder: (context, receiveExactAmount) {
                          return Switch(
                            value: receiveExactAmount,
                            activeThumbColor: context.appColors.onSecondary,
                            activeTrackColor: context.appColors.secondary,
                            inactiveThumbColor: context.appColors.onSecondary,
                            inactiveTrackColor: context.appColors.surface,
                            trackOutlineColor:
                                WidgetStateProperty.resolveWith<Color?>(
                                  (Set<WidgetState> states) =>
                                      Colors.transparent,
                                ),
                            onChanged: (value) {
                              context.read<TransferBloc>().add(
                                TransferEvent.receiveExactAmountToggled(value),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const Gap(24),
                  BlocSelector<TransferBloc, TransferState, bool>(
                    selector: (state) =>
                        state.isStarting ||
                        state.isCreatingSwap ||
                        state.continueClicked,
                    builder: (context, isLoading) {
                      return BBButton.big(
                        label: context.loc.swapContinueButton,
                        bgColor: context.appColors.secondary,
                        textColor: context.appColors.onSecondary,
                        disabled: isLoading,
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) {
                            return;
                          }
                          context.read<TransferBloc>().add(
                            TransferEvent.swapCreated(_amountController.text),
                          );
                        },
                      );
                    },
                  ),
                  const Gap(24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
