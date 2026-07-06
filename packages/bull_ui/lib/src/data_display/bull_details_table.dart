import 'package:bull_ui/src/feedback/bull_shimmer.dart';
import 'package:bull_ui/src/feedback/bull_snack_bar.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

/// A bordered, padded container that stacks [BullDetailsTableItem] rows with
/// hairline dividers between them — duplicated from
/// `core/widgets/tables/details_table.dart` (`DetailsTable`).
///
/// Used to present key/value transaction or address details. The fill is
/// [BullTheme.surface], the border and dividers use [BullTheme.border], and a
/// soft drop shadow derives from [BullTheme.onSurface].
class BullDetailsTable extends StatelessWidget {
  const BullDetailsTable({super.key, required this.items});

  /// The rows to render (typically [BullDetailsTableItem]s), separated by
  /// dividers.
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.onSurface.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i != items.length - 1) Divider(color: colors.border),
          ],
        ],
      ),
    );
  }
}

/// A single label/value row for [BullDetailsTable] — duplicated from
/// `core/widgets/tables/details_table_item.dart` (`DetailsTableItem`).
///
/// Shows [label] on the left and a right-aligned value on the right. The value
/// is [displayWidget] if provided, otherwise [displayValue] as text, otherwise
/// a [BullShimmerLine] placeholder. When [copyValue] is non-empty a copy icon
/// is shown that writes to the clipboard and surfaces a [BullSnackBar]. When
/// [expandableChild] is provided an expand/collapse toggle reveals it below.
class BullDetailsTableItem extends StatefulWidget {
  const BullDetailsTableItem({
    super.key,
    required this.label,
    this.displayValue,
    this.copyValue,
    this.isUnderline = false,
    this.expandableChild,
    this.displayWidget,
    this.copiedMessage = 'Copied to clipboard',
  });

  /// Left-hand row label.
  final String label;

  /// Right-hand value rendered as text when [displayWidget] is null.
  final String? displayValue;

  /// Value written to the clipboard by the copy icon; the icon is hidden when
  /// this is null or empty.
  final String? copyValue;

  /// Whether to underline the [displayValue] text.
  final bool isUnderline;

  /// Optional content revealed by the expand toggle.
  final Widget? expandableChild;

  /// Optional custom value widget, used instead of [displayValue].
  final Widget? displayWidget;

  /// Toast message shown after a successful copy.
  final String copiedMessage;

  @override
  State<BullDetailsTableItem> createState() => _BullDetailsTableItemState();
}

class _BullDetailsTableItemState extends State<BullDetailsTableItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              // Label
              Expanded(
                flex: 2,
                child: Text(
                  widget.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurface),
                ),
              ),

              // Value + copy icon + expand icon
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child:
                          widget.displayWidget ??
                          (widget.displayValue != null
                              ? Text(
                                  widget.displayValue!,
                                  textAlign: TextAlign.end,
                                  overflow: TextOverflow.clip,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colors.onSurface,
                                    decoration: widget.isUnderline
                                        ? TextDecoration.underline
                                        : TextDecoration.none,
                                  ),
                                )
                              : const BullShimmerLine()),
                    ),
                    const Gap(8),
                    if (widget.copyValue != null &&
                        widget.copyValue!.isNotEmpty)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          splashColor: colors.primary.withValues(alpha: 0.12),
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: widget.copyValue!),
                            );
                            BullSnackBar.show(
                              context,
                              message: widget.copiedMessage,
                            );
                          },
                          child: Icon(
                            Icons.copy_outlined,
                            size: 18,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    if (widget.expandableChild != null) ...[
                      const Gap(8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _expanded = !_expanded;
                            });
                          },
                          child: Icon(
                            _expanded ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_expanded && widget.expandableChild != null)
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: widget.expandableChild,
          ),
      ],
    );
  }
}
