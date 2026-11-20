import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:bull_ui/src/feedback/bull_shimmer.dart';
import 'package:bull_ui/src/feedback/bull_snack_bar.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:bull_ui/src/layout/gap.dart';

/// A bordered, padded container that stacks [BullDetailsTableItem] rows with
/// hairline dividers between them.
///
/// Used to present key/value transaction or address details. The fill is
/// [BullTheme.surface], the border and dividers use [BullTheme.outline], and a
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
        border: Border.all(color: colors.outline),
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
            if (i != items.length - 1) Divider(color: colors.outline),
          ],
        ],
      ),
    );
  }
}

/// A single label/value row for [BullDetailsTable].
///
/// Shows [label] on the left and a right-aligned value on the right. The value
/// is [displayWidget] if provided, otherwise [displayValue] as text, otherwise
/// a [BullShimmerLine] placeholder. When [copyValue] is non-empty a copy icon
/// is shown that writes to the clipboard, then calls [onCopied] or, when that
/// is null, surfaces a [BullSnackBar]. When [expandableChild] is provided an
/// expand/collapse toggle reveals it below.
class BullDetailsTableItem extends StatefulWidget {
  const BullDetailsTableItem({
    super.key,
    required this.label,
    this.displayValue,
    this.copyValue,
    this.isUnderline = false,
    this.expandableChild,
    this.displayWidget,
    this.initiallyExpanded = false,
    this.copiedMessage = 'Copied to clipboard',
    this.onCopied,
    this.onValueTap,
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

  /// Whether [expandableChild] starts revealed.
  final bool initiallyExpanded;

  /// Toast message shown after a successful copy.
  final String copiedMessage;

  /// Called after a successful copy instead of the default [BullSnackBar], for
  /// screens that confirm the copy their own way.
  final VoidCallback? onCopied;

  /// Opens an action from the text value and adds a trailing chevron.
  final VoidCallback? onValueTap;

  @override
  State<BullDetailsTableItem> createState() => _BullDetailsTableItemState();
}

class _BullDetailsTableItemState extends State<BullDetailsTableItem> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final value = widget.displayValue;
    final onValueTap = widget.onValueTap;
    final display =
        widget.displayWidget ??
        switch ((value, onValueTap)) {
          (null, _) => const BullShimmerLine(),
          (final value?, null) => Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.clip,
            style: context.bullType.body.copyWith(
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
              decoration: widget.isUnderline
                  ? TextDecoration.underline
                  : TextDecoration.none,
            ),
          ),
          (final value?, final onTap?) => Semantics(
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        textAlign: TextAlign.end,
                        style: context.bullType.body.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 20, color: colors.primary),
                  ],
                ),
              ),
            ),
          ),
        };

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
                  style: context.bullType.body.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),

              // Value + copy icon + expand icon
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(child: display),
                    const Gap(8),
                    if (widget.copyValue != null &&
                        widget.copyValue!.isNotEmpty)
                      Material(
                        color: colors.transparent,
                        child: InkWell(
                          splashColor: colors.primary.withValues(alpha: 0.12),
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: widget.copyValue!),
                            );
                            final onCopied = widget.onCopied;
                            if (onCopied != null) {
                              onCopied();
                            } else {
                              BullSnackBar.show(
                                context,
                                message: widget.copiedMessage,
                              );
                            }
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
                        color: colors.transparent,
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
