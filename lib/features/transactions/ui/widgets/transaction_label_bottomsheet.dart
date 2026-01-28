import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
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

  await BlurredBottomSheet.show(
    context: context,
    child: BlocProvider.value(
      value: detailsCubit,
      child: TransactionLabelBottomsheet(
        distinctLabelsFuture: detailsCubit.fetchDistinctLabels(),
      ),
    ),
  );
}

class TransactionLabelBottomsheet extends StatefulWidget {
  const TransactionLabelBottomsheet({
    super.key,
    required this.distinctLabelsFuture,
  });

  final Future<Set<String>> distinctLabelsFuture;

  @override
  State<TransactionLabelBottomsheet> createState() =>
      _TransactionLabelBottomsheetState();
}

class _TransactionLabelBottomsheetState
    extends State<TransactionLabelBottomsheet> {
  final _controller = TextEditingController();
  String get trimmedLabel => _controller.text.trim();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildSuggestions(List<String> existingLabels) {
    final height = Device.screen.height * 0.05;
    final currentText = trimmedLabel.toLowerCase();

    final suggestions = existingLabels
        .where((label) => label.toLowerCase().startsWith(currentText))
        // don't show system labels
        .where((label) => !LabelSystem.isSystemLabel(label))
        .toList();

    if (suggestions.isEmpty ||
        (suggestions.length == 1 &&
            suggestions.first.toLowerCase() == currentText)) {
      return SizedBox(height: height);
    }

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: .horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => SizedBox(width: Device.screen.width * 0.01),
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return _LabelSuggestionChip(
            label: suggestion,
            onTap: () => setState(() => _controller.text = suggestion),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransactionDetailsCubit>().state;

    return FutureBuilder<Set<String>>(
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
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            children: [
              Gap(Device.screen.height * 0.01),
              Row(
                children: [
                  const Spacer(),
                  BBText(
                    context.loc.transactionNoteAddTitle,
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
              _buildSuggestions(snapshot.data?.toList() ?? []),
              Gap(Device.screen.height * 0.01),
              BBInputText(
                controller: _controller,
                value: _controller.text,
                hint: context.loc.transactionNoteHint,
                hintStyle: context.font.bodyLarge?.copyWith(
                  color: context.appColors.textMuted,
                ),
                maxLines: 1,
                maxLength: NoteValidator.maxNoteLength,
                onChanged: (_) => setState(() {}),
              ),
              if (state.err != null) ...[
                Gap(Device.screen.height * 0.01),
                BBText(
                  state.err!.toString(),
                  style: context.font.bodySmall?.copyWith(
                    color: context.appColors.error,
                  ),
                ),
              ],
              Gap(Device.screen.height * 0.03),
              BBButton.big(
                label: context.loc.transactionNoteSaveButton,
                disabled: state.err != null || trimmedLabel.isEmpty,
                onPressed: () {
                  final validation = NoteValidator.validate(trimmedLabel);
                  if (validation.isValid) {
                    context
                        .read<TransactionDetailsCubit>()
                        .saveTransactionLabel(
                          NewLabel.tx(
                            transactionId: state.walletTransaction!.txId,
                            label: trimmedLabel,
                          ),
                        );
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
