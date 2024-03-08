import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/transaction/bloc/transaction_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';

class TxLabelTextField extends HookWidget {
  const TxLabelTextField({super.key});

  @override
  Widget build(BuildContext context) {
    final storedLabel = context.select((TransactionCubit x) => x.state.tx.label ?? '');
    final showButton = context.select(
      (TransactionCubit x) => x.state.showSaveButton(),
      // && storedLabel.isEmpty,
    );
    final label = context.select((TransactionCubit x) => x.state.label);

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 45,
            child: BBTextInput.small(
              // disabled: storedLabel.isNotEmpty,
              hint: storedLabel.isNotEmpty ? storedLabel : 'Enter Label',
              value: label,
              onChanged: (value) {
                context.read<TransactionCubit>().labelChanged(value);
              },
            ),
          ),
        ),
        const Gap(8),
        BBButton.big(
          disabled: !showButton,
          fillWidth: true,
          onPressed: () {
            FocusScope.of(context).requestFocus(FocusNode());
            context.read<TransactionCubit>().saveLabelClicked();
          },
          label: 'SAVE',
        ),
      ],
    );
  }
}
