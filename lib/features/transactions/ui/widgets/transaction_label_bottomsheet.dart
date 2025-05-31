import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/inputs/text_input.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class TransactionLabelBottomsheet extends StatefulWidget {
  const TransactionLabelBottomsheet({super.key});

  @override
  State<TransactionLabelBottomsheet> createState() =>
      _TransactionLabelBottomsheetState();
}

class _TransactionLabelBottomsheetState
    extends State<TransactionLabelBottomsheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(22),
          Row(
            children: [
              const Gap(22),
              const Spacer(),
              BBText('Add note', style: context.font.headlineMedium),
              const Spacer(),
              IconButton(
                onPressed: () {
                  context.pop();
                },
                color: context.colour.secondary,
                icon: const Icon(Icons.close_sharp),
              ),
            ],
          ),
          const Gap(33),
          BBInputText(
            controller: _controller,
            hint: 'Note',
            hintStyle: context.font.bodyLarge?.copyWith(
              color: context.colour.surfaceContainer,
            ),
            value: '',
            onChanged: (note) {
              // No need to handle note changes here, as we will save it on button press
            },
          ),
          const Gap(40),
          BBButton.big(
            label: 'Save',
            onPressed: () {
              context.read<TransactionDetailsCubit>().saveTransactionNote(
                _controller.text,
              );
              context.pop();
            },
            bgColor: context.colour.secondary,
            textColor: context.colour.onSecondary,
          ),
          const Gap(24),
        ],
      ),
    );
  }
}
