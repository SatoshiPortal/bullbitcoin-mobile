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
  const BullDetailsTable({
    super.key,
    required this.items,
    this.flat = false,
    this.dividerHeight,
  });

  /// The rows to render (typically [BullDetailsTableItem]s), separated by
  /// dividers.
  final List<Widget> items;

  /// Omits only the outer frame, fill, shadow and padding.
  final bool flat;

  /// Null keeps the themed divider spacing.
  final double? dividerHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Container(
      padding: flat ? EdgeInsets.zero : const EdgeInsets.all(16),
      decoration: flat
          ? null
          : BoxDecoration(
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
            if (i != items.length - 1)
              Divider(color: colors.outline, height: dividerHeight),
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
    this.compact = false,
  });

  /// Left-hand row label.
  final String label;

  /// Compact rows grow naturally and keep 48 dp actions.
  final bool compact;

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

  @override
  State<BullDetailsTableItem> createState() => _BullDetailsTableItemState();
}

class _BullDetailsTableItemState extends State<BullDetailsTableItem> {
  late bool _expanded = widget.initiallyExpanded;

  Widget _actionIcon(IconData data, String? label) {
    final icon = Icon(data, size: 18, color: context.bull.primary);
    return widget.compact
        ? Semantics(
            button: true,
            label: label,
            expanded: data == Icons.copy_outlined ? null : _expanded,
            child: SizedBox.square(dimension: 48, child: Center(child: icon)),
          )
        : icon;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final labels = widget.compact ? MaterialLocalizations.of(context) : null;
    final wideLabel = widget.compact && (widget.copyValue?.isEmpty ?? true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: widget.compact
              ? const BoxConstraints(minHeight: 48)
              : null,
          padding: EdgeInsets.symmetric(vertical: widget.compact ? 0 : 8),
          child: Row(
            children: [
              // Label
              Expanded(
                flex: wideLabel ? 3 : 2,
                child: Text(
                  widget.label,
                  style: context.bullType.body.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),

              // Value + copy icon + expand icon
              Expanded(
                flex: wideLabel ? 2 : 3,
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
                                  style: context.bullType.body
                                      .copyWith(fontWeight: FontWeight.w500)
                                      .copyWith(
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
                          child: _actionIcon(
                            Icons.copy_outlined,
                            labels?.copyButtonLabel,
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
                          child: _actionIcon(
                            _expanded ? Icons.expand_less : Icons.expand_more,
                            _expanded
                                ? labels?.expandedIconTapHint
                                : labels?.collapsedIconTapHint,
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
