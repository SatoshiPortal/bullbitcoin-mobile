import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/dialpad/dial_pad.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/price_input/balance_row.dart';
import 'package:bb_mobile/core/widgets/price_input/price_input.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/spark/presentation/cubit.dart';
import 'package:bb_mobile/features/spark/presentation/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SendPage extends StatefulWidget {
  const SendPage({super.key});

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  final amountController = TextEditingController();

  void _updateAmount(String amount, int max) {
    final intAmount = int.tryParse(amount);
    if (intAmount != null && intAmount > max) return;

    amountController.text = amount;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SparkCubit, SparkState>(
      listener: (context, state) {
        if (state.error != null) {
          SnackBarUtils.showSnackBar(context, state.error!.message);
          context.read<SparkCubit>().clearError();
        }

        // If transaction succeeded, pop back
        if (state.txid.isNotEmpty) {
          context.pop();
        }
      },
      builder: (context, state) {
        final cubit = context.read<SparkCubit>();
        final amount = int.tryParse(amountController.text);
        final isValidAmount = amount != null && amount > 0;
        final hasAddress = state.sendAddress.isNotEmpty;

        final fiatAmount = FormatAmount.fiat(
          ConvertAmount.satsToFiat(amount ?? 0, state.exchangeRate),
          state.currencyCode,
        );

        final availableBalance = state.sparkBalance?.balanceSats ?? 0;

        return Scaffold(
          appBar: AppBar(
            title: BBText('Send', style: context.font.headlineMedium),
          ),
          body: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  BBText("Recipient's address", style: context.font.bodyMedium),
                  BBInputText(
                    onlyPaste: true,
                    onChanged: cubit.updateSendAddress,
                    value: state.sendAddress,
                    hint:
                        'Lightning invoice, Spark address, or Bitcoin address',
                    hintStyle: context.font.bodyLarge?.copyWith(
                      color: context.colour.surfaceContainer,
                    ),
                    maxLines: 2,
                    rightIcon: Icon(
                      Icons.paste_sharp,
                      color: context.colour.secondary,
                      size: 20,
                    ),
                    onRightTap: () {
                      Clipboard.getData(Clipboard.kTextPlain).then((value) {
                        final clipboard = value?.text;
                        if (clipboard == null) return;
                        cubit.updateSendAddress(clipboard);
                      });
                    },
                  ),
                ],
              ),

              Column(
                children: [
                  PriceInput(
                    currency: 'sats',
                    amountEquivalent: fiatAmount,
                    availableCurrencies: state.fiatCurrencyCodes,
                    amountController: amountController,
                    onNoteChanged: null,
                    onCurrencyChanged: cubit.onSendCurrencyCodeChanged,
                    error: null,
                    focusNode: null,
                    readOnly: true,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: BalanceRow(
                      title: 'Available Balance',
                      balance: availableBalance.toString(),
                      currencyCode: 'sats',
                      onMaxPressed:
                          () => _updateAmount(
                            availableBalance.toString(),
                            availableBalance,
                          ),
                      walletLabel: null,
                    ),
                  ),
                ],
              ),

              Column(
                children: [
                  DialPad(
                    onNumberPressed: (pressed) {
                      if (pressed == '.') return;
                      _updateAmount(
                        amountController.text + pressed,
                        availableBalance,
                      );
                    },
                    onBackspacePressed: () {
                      final amount = amountController.text;
                      if (amount.isEmpty) return;

                      final newAmount = amount.substring(0, amount.length - 1);
                      _updateAmount(newAmount, availableBalance);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: BBButton.big(
                      label: 'Confirm',
                      onPressed: () async {
                        if (!isValidAmount || !hasAddress) return;

                        try {
                          await cubit.prepareSendPayment(amount);

                          await cubit.sendPayment();
                        } catch (e) {
                          if (!context.mounted) return;
                          SnackBarUtils.showSnackBar(context, e.toString());
                        }
                      },
                      disabled:
                          !isValidAmount || !hasAddress || state.isLoading,
                      bgColor: context.colour.primary,
                      textColor: context.colour.onPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
