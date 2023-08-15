import 'package:bb_mobile/_model/currency.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
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
    final sendAll = context.select((SendCubit cubit) => cubit.state.sendAllCoin);
    if (sendAll) return const SizedBox.shrink();
    final balance = context.select((WalletBloc cubit) => cubit.state.balance?.total ?? 0);
    final isSats = context.select((SettingsCubit cubit) => cubit.state.unitsInSats);
    final amount = context.select((SendCubit cubit) => cubit.state.amount);

    final amountStr = context.select(
      (SettingsCubit cubit) => cubit.state.getAmountInUnits(
        sendAll ? balance : amount,
        removeText: true,
        hideZero: true,
        removeEndZeros: true,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.title('    Amount'),
        const Gap(4),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: sendAll ? 0.5 : 1,
          child: Row(
            children: [
              IgnorePointer(
                ignoring: sendAll,
                child: Focus(
                  focusNode: _focusNode,
                  child: BBAmountInput(
                    disabled: sendAll,
                    value: amountStr,
                    hint: 'Enter amount',
                    onRightTap: () {
                      context.read<SettingsCubit>().toggleUnitsInSats();
                    },
                    isSats: isSats,
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
                      context.read<SendCubit>().updateAmount(txt);
                    },
                  ),
                ),
              ),
              const Gap(8),
              const CurrencyDropDown(),
            ],
          ),
        ),
        const Gap(8),
        const ConversionAmt(),
      ],
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();

    super.dispose();
  }
}

class CurrencyDropDown extends StatelessWidget {
  const CurrencyDropDown({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = context.select((SendCubit cubit) => cubit.state.selectedCurrency);
    final currencyList = context.select((SendCubit cubit) => cubit.state.updatedCurrencyList());

    return DropdownButton<String>(
      value: currency?.name,
      icon: const Icon(Icons.arrow_downward),
      // iconSize: 24,
      elevation: 16,
      style: const TextStyle(color: Colors.deepPurple),
      underline: Container(
        height: 2,
        color: Colors.deepPurpleAccent,
      ),
      onChanged: (String? amt) {
        if (amt == null) return;
        context.read<SendCubit>().updateCurrency(amt.toLowerCase());
      },
      items: currencyList.map<DropdownMenuItem<String>>((Currency value) {
        return DropdownMenuItem<String>(
          value: value.name,
          child: Text(value.getFullName()),
        );
      }).toList(),
    );
  }
}

class ConversionAmt extends StatelessWidget {
  const ConversionAmt({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
