import 'package:bb_mobile/core/utils/note_validator.dart';
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
    final state = context.watch<TransactionDetailsCubit>().state;

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
            value: state.note ?? '',
            maxLength: NoteValidator.maxNoteLength,
            onChanged: (note) {
              context.read<TransactionDetailsCubit>().onNoteChanged(note);
            },
          ),
          if (context.read<TransactionDetailsCubit>().state.err != null) ...[
            const Gap(8),
            BBText(
              state.err!.toString(),
              style: context.font.bodySmall?.copyWith(color: Colors.red),
            ),
          ],
          const Gap(40),
          BBButton.big(
            label: 'Save',
            disabled: state.err != null || _controller.text.trim().isEmpty,
            onPressed: () {
              final validation = NoteValidator.validate(_controller.text);
              if (validation.isValid) {
                context.read<TransactionDetailsCubit>().saveTransactionNote(
                  _controller.text.trim(),
                );
                context.pop();
              }
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
