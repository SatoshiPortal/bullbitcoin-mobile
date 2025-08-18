import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/note_validator.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

Future<void> showTransactionLabelBottomSheet(
  BuildContext context, {
  String? initialNote,
  Function(String)? onEditComplete,
}) async {
  final detailsCubit = context.read<TransactionDetailsCubit>();

  await showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    backgroundColor: context.colour.onPrimary,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: double.infinity),
    builder: (context) {
      return BlocProvider.value(
        value: detailsCubit,
        child: TransactionLabelBottomsheet(
          initialNote: initialNote,
          onEditComplete: onEditComplete,
        ),
      );
    },
  );
}

class TransactionLabelBottomsheet extends StatefulWidget {
  const TransactionLabelBottomsheet({
    super.key,
    this.initialNote,
    this.onEditComplete,
  });

  final String? initialNote;
  final Function(String)? onEditComplete;

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
    _controller = TextEditingController(text: widget.initialNote ?? '');
    if (widget.initialNote != null) {
      context.read<TransactionDetailsCubit>().onNoteChanged(
        widget.initialNote!,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransactionDetailsCubit>().state;
    final isEditing = widget.initialNote != null;

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
              BBText(
                isEditing ? 'Edit note' : 'Add note',
                style: context.font.headlineMedium,
              ),
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
            maxLines: 2,
            value: state.note ?? widget.initialNote ?? '',
            maxLength: NoteValidator.maxNoteLength,
            onChanged: (note) {
              context.read<TransactionDetailsCubit>().onNoteChanged(note);
            },
          ),
          if (state.err != null) ...[
            const Gap(8),
            BBText(
              state.err!.toString(),
              style: context.font.bodySmall?.copyWith(color: Colors.red),
            ),
          ],
          const Gap(40),
          BBButton.big(
            label: isEditing ? 'Update' : 'Save',
            disabled: state.err != null || _controller.text.trim().isEmpty,
            onPressed: () {
              final validation = NoteValidator.validate(_controller.text);
              if (validation.isValid) {
                if (widget.onEditComplete != null) {
                  widget.onEditComplete!(_controller.text.trim());
                } else {
                  context.read<TransactionDetailsCubit>().saveTransactionNote();
                }
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
