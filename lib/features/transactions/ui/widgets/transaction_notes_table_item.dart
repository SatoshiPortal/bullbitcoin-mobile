import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/transaction_label_bottomsheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TransactionNotesTableItem extends StatelessWidget {
  const TransactionNotesTableItem({super.key, required this.notes});

  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: BBText(
              'Transaction notes',
              style: context.font.bodyMedium?.copyWith(
                color: context.colour.surfaceContainer,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children:
                  notes.map((note) {
                    return NoteChip(
                      note: note,
                      onEdit: () => _showEditNoteBottomSheet(context, note),
                      onDelete:
                          () => context
                              .read<TransactionDetailsCubit>()
                              .deleteTransactionNote(note),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditNoteBottomSheet(
    BuildContext context,
    String currentNote,
  ) async {
    final cubit = context.read<TransactionDetailsCubit>();

    await showTransactionLabelBottomSheet(
      context,
      initialNote: currentNote,
      onEditComplete: (String newNote) {
        if (newNote != currentNote) {
          cubit.editTransactionNote(currentNote, newNote);
        }
      },
    );
  }
}

class NoteChip extends StatelessWidget {
  const NoteChip({
    super.key,
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });

  final String note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    // Calculate available width (approximate)
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth * 0.8; // Use at most 80% of screen width

    return Container(
      decoration: BoxDecoration(
        color: context.colour.onPrimary,
        border: Border.all(color: context.colour.surface),
        borderRadius: BorderRadius.circular(3),
      ),
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,

          children: [
            Flexible(
              child: GestureDetector(
                onTap: onEdit,
                child: BBText(
                  note,
                  style: context.font.bodySmall?.copyWith(
                    color: context.colour.outlineVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.close, size: 16, color: context.colour.primary),
            ),
          ],
        ),
      ),
    );
  }
}
