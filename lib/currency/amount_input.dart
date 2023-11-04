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

class EnterAmount extends StatefulWidget {
  const EnterAmount({super.key});

  @override
  State<EnterAmount> createState() => _EnterAmountState();
}

class _EnterAmountState extends State<EnterAmount> {
  final FocusNode _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    final _ = context.select((CurrencyCubit cubit) => cubit.state.currency);

    final sendAll = context.select((SendCubit cubit) => cubit.state.sendAllCoin);

    final isSats = context.select((CurrencyCubit cubit) => cubit.state.unitsInSats);

    final fiatSelected = context.select((CurrencyCubit cubit) => cubit.state.fiatSelected);
    final tempAmt = context.select((SendCubit cubit) => cubit.state.tempAmount);

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
                      child: CurrencyDropDown(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const Gap(4),
        if (!sendAll) const ConversionAmt(),
      ],
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();

    super.dispose();
  }
}
