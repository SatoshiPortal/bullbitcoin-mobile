import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/currency/conversion.dart';
import 'package:bb_mobile/currency/dropdown.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class EnterSendAmount extends StatefulWidget {
  const EnterSendAmount({super.key});

  @override
  State<EnterSendAmount> createState() => _EnterSendAmountState();
}

class _EnterSendAmountState extends State<EnterSendAmount> {
  final FocusNode _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    final _ = context.select((CurrencyCubit cubit) => cubit.state.currency);

    final sendAll = context.select((SendCubit cubit) => cubit.state.sendAllCoin);
    // if (sendAll) return const SizedBox.shrink();
    final isSats = context.select((CurrencyCubit cubit) => cubit.state.unitsInSats);

    final fiatSelected = context.select((CurrencyCubit cubit) => cubit.state.fiatSelected);
    final tempAmt = context.select((SendCubit cubit) => cubit.state.tempAmount);

    // var amountStr = '';
    // if (!fiatSelected)
    //   amountStr = context.select(
    //     (SettingsCubit cubit) => cubit.state.getAmountInUnits(
    //       sendAll ? balance : amount,
    //       removeText: true,
    //       hideZero: true,
    //       removeEndZeros: true,
    //       isSats: isSats,
    //     ),
    //   );
    // else
    //   amountStr = fiatAmt.toStringAsFixed(2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.title('    Amount'),
        const Gap(4),
        if (sendAll) ...[
          const Gap(4),
          const BBText.bodySmall('    Entire balance will be sent'),
          const Gap(4),
        ] else
          IgnorePointer(
            ignoring: sendAll,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: sendAll ? 0.5 : 1,
              child: Stack(
                children: [
                  Focus(
                    focusNode: _focusNode,
                    child: BBAmountInput(
                      disabled: sendAll,
                      value: tempAmt,
                      hint: 'Enter amount',
                      // onRightTap: () {
                      //   // context.read<SettingsCubit>().toggleUnitsInSats();
                      // },
                      isSats: isSats,
                      btcFormatting: !isSats && !fiatSelected,
                      onChanged: (txt) {
                        // final aLen = amountStr.length;
                        // final tLen = txt.length;

                        // print('\n\n');
                        // print('||--- $txt');

                        // if ((tLen - aLen) > 1 || (aLen - tLen) > 1) {
                        //   return;
                        // }

                        // var clean = txt.replaceAll(',', '');
                        // if (isSats)
                        //   clean = clean.replaceAll('.', '');
                        // else if (!txt.contains('.')) {
                        //   return;
                        // }
                        // final amt = context.read<SettingsCubit>().state.getSatsAmount(clean);
                        // print('----- $amt');

                        context.read<CurrencyCubit>().updateAmount(txt);
                      },
                    ),
                  ),
                  const CenterRight(
                    child: Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: SendCurrencyDropDown(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const Gap(4),
        if (!sendAll) const SendConversionAmt(),
      ],
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();

    super.dispose();
  }
}

class InvoiceAmountField extends StatefulWidget {
  const InvoiceAmountField({super.key});

  @override
  State<InvoiceAmountField> createState() => _InvoiceAmountFieldState();
}

class _InvoiceAmountFieldState extends State<InvoiceAmountField> {
  final FocusNode _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    final _ = context.select((CurrencyCubit cubit) => cubit.state.currency);

    final isSats = context.select((CurrencyCubit cubit) => cubit.state.unitsInSats);

    final fiatSelected = context.select((CurrencyCubit cubit) => cubit.state.fiatSelected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: 1,
          child: Stack(
            children: [
              Focus(
                focusNode: _focusNode,
                child: BBAmountInput(
                  disabled: false,
                  hint: 'Enter amount',
                  isSats: isSats,
                  btcFormatting: !isSats && !fiatSelected,
                  onChanged: (txt) {
                    context.read<CurrencyCubit>().updateAmount(txt);
                  },
                ),
              ),
              const CenterRight(
                child: Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: ReceiveCurrencyDropDown(),
                ),
              ),
            ],
          ),
        ),
        const Gap(4),
        const ReceiveConversionAmt(),
      ],
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();

    super.dispose();
  }
}
