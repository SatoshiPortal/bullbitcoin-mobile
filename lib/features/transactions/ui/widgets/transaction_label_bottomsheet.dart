import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/note_validator.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
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
    backgroundColor: context.appColors.surface,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: double.infinity),
    builder: (context) {
      return BlocProvider.value(
        value: detailsCubit,
        child: TransactionLabelBottomsheet(
          initialNote: initialNote,
          onEditComplete: onEditComplete,
          distinctLabelsFuture: detailsCubit.fetchDistinctLabels(),
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
    required this.distinctLabelsFuture,
  });

  final String? initialNote;
  final Function(String)? onEditComplete;
  final Future<List<String>> distinctLabelsFuture;

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

  void _onSuggestionTap(String label) {
    _controller.text = label;
    context.read<TransactionDetailsCubit>().onNoteChanged(label);
  }

  Widget _buildSuggestions(List<String> existingLabels) {
    final height = Device.screen.height * 0.05;
    final currentText = _controller.text.trim().toLowerCase();

    final suggestions =
        existingLabels
            .where((label) => label.toLowerCase().startsWith(currentText))
            .toList();

    if (suggestions.isEmpty ||
        (suggestions.length == 1 &&
            suggestions.first.toLowerCase() == currentText)) {
      return SizedBox(height: height);
    }

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => SizedBox(width: Device.screen.width * 0.01),
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return _LabelSuggestionChip(
            label: suggestion,
            onTap: () => _onSuggestionTap(suggestion),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransactionDetailsCubit>().state;
    final isEditing = widget.initialNote != null;

    return FutureBuilder<List<String>>(
      future: widget.distinctLabelsFuture,
      builder: (context, snapshot) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            Device.screen.width * 0.03,
            0,
            Device.screen.width * 0.03,
            MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Gap(Device.screen.height * 0.01),
              Row(
                children: [
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
                    color: context.appColors.onSurface,
                    icon: const Icon(Icons.close_sharp),
                  ),
                ],
              ),
              FadingLinearProgress(
                trigger: snapshot.connectionState == ConnectionState.waiting,
              ),
              Gap(Device.screen.height * 0.01),
              _buildSuggestions(snapshot.data ?? []),
              Gap(Device.screen.height * 0.01),
              BBInputText(
                controller: _controller,
                hint: 'Note',
                hintStyle: context.font.bodyLarge?.copyWith(
                  color: context.appColors.textMuted,
                ),
                maxLines: 2,
                value: state.note ?? widget.initialNote ?? '',
                maxLength: NoteValidator.maxNoteLength,
                onChanged: (note) {
                  context.read<TransactionDetailsCubit>().onNoteChanged(note);
                },
              ),
              if (state.err != null) ...[
                Gap(Device.screen.height * 0.01),
                BBText(
                  state.err!.toString(),
                  style: context.font.bodySmall?.copyWith(color: context.appColors.error),
                ),
              ],
              Gap(Device.screen.height * 0.03),
              BBButton.big(
                label: isEditing ? 'Update' : 'Save',
                disabled: state.err != null || _controller.text.trim().isEmpty,
                onPressed: () {
                  final validation = NoteValidator.validate(_controller.text);
                  if (validation.isValid) {
                    if (widget.onEditComplete != null) {
                      widget.onEditComplete!(_controller.text.trim());
                    } else {
                      context
                          .read<TransactionDetailsCubit>()
                          .saveTransactionNote();
                    }
                    context.pop();
                  }
                },
                bgColor: context.appColors.onSurface,
                textColor: context.appColors.surface,
              ),
              Gap(Device.screen.height * 0.03),
            ],
          ),
        );
      },
    );
  }
}

class _LabelSuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _LabelSuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Device.screen.width * 0.03,
          vertical: Device.screen.height * 0.01,
        ),
        height: Device.screen.height * 0.05,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: context.appColors.surface,
          border: Border.all(color: context.appColors.border),
        ),
        child: Center(child: BBText(label, style: context.font.bodyLarge)),
      ),
    );
  }
}
