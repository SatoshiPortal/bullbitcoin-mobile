import 'package:bull_ui/bull_ui.dart';

/// One line of an [ArkSummaryBox]: a muted label and its value.
typedef ArkSummaryRow = ({String label, String value});

/// A compact card of label/value lines, as used by the confirmation sheets.
class ArkSummaryBox extends StatelessWidget {
  final List<ArkSummaryRow> rows;

  const ArkSummaryBox({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BullSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(context.bullShapes.card),
      ),
      child: Column(
        children: [
          for (final (index, row) in rows.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: BullSpacing.sm),
              decoration: index == rows.length - 1
                  ? null
                  : BoxDecoration(
                      border: Border(bottom: BorderSide(color: colors.border)),
                    ),
              child: Row(
                children: [
                  Expanded(
                    child: BullText(
                      row.label,
                      role: BullTextRole.body,
                      color: colors.textMuted,
                    ),
                  ),
                  const Gap(BullSpacing.sm),
                  BullText(
                    row.value,
                    role: BullTextRole.body,
                    fontWeight: FontWeight.w600,
                    textAlign: TextAlign.end,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
