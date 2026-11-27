import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:bull_ui/src/feedback/bull_shimmer.dart';
import 'package:bull_ui/src/feedback/bull_snack_bar.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

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
/// a [BullShimmerLine] placeholder. When [copyValue] is non-empty a copy action
/// is shown that writes to the clipboard, then calls [onCopied] or, when that
/// is null, surfaces a [BullSnackBar]. When [expandableChild] is provided an
/// expand/collapse action reveals it below and publishes its expanded state.
/// Both actions are 48×48 targets named after their row.
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
  }) : assert(
         onValueTap == null || (displayValue != null && displayWidget == null),
         'onValueTap requires a text value. Custom widgets own their actions.',
       );

  /// Left-hand row label.
  final String label;

  /// Right-hand value rendered as text when [displayWidget] is null.
  final String? displayValue;

  /// Value written to the clipboard by the copy action; the action is hidden
  /// when this is null or empty.
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

  /// Opens an action from [displayValue] and adds a trailing chevron.
  /// A custom [displayWidget] owns its own interactions.
  final VoidCallback? onValueTap;

  @override
  State<BullDetailsTableItem> createState() => _BullDetailsTableItemState();
}

class _BullDetailsTableItemState extends State<BullDetailsTableItem> {
  late bool _expanded = widget.initiallyExpanded;

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    final onCopied = widget.onCopied;
    if (onCopied != null) {
      onCopied();
    } else {
      BullSnackBar.show(context, message: widget.copiedMessage);
    }
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final material = MaterialLocalizations.of(context);
    final value = widget.displayValue;
    final onValueTap = widget.onValueTap;
    final copyValue = widget.copyValue;
    final expandable = widget.expandableChild != null;
    // Material's translated copy/expand wording, qualified with the row label
    // so that assistive technology reads each action against its own row
    // instead of announcing several identical "Copy" or "Expand" buttons.
    final copyLabel = '${material.copyButtonLabel} ${widget.label}';
    final expandLabel =
        '${_expanded ? material.expandedIconTapHint : material.collapsedIconTapHint}'
        ' ${widget.label}';
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

              // Value + copy action + expand action
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(child: display),
                    // The actions carry their own 48 dp padding, so no extra
                    // gap is added next to them: the layout stays as wide as
                    // the two touch targets require.
                    if (copyValue != null && copyValue.isNotEmpty)
                      _DetailsTableAction(
                        label: copyLabel,
                        icon: Icons.copy_outlined,
                        color: colors.primary,
                        onPressed: () => _copy(copyValue),
                      ),
                    if (expandable)
                      _DetailsTableAction(
                        label: expandLabel,
                        icon: _expanded ? Icons.expand_less : Icons.expand_more,
                        color: colors.primary,
                        onPressed: _toggleExpanded,
                        expanded: _expanded,
                      ),
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

/// A 48×48 icon action of a [BullDetailsTableItem].
///
/// The glyph stays 18 dp, but the touch target meets the 48 dp guideline. The
/// action is announced by [label] and shows it as its tooltip; the inner
/// button semantics are excluded so the action is a single node named by the
/// row it belongs to, never a duplicate of the surrounding text. [expanded]
/// publishes the disclosure state of an expand/collapse action.
class _DetailsTableAction extends StatelessWidget {
  const _DetailsTableAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.expanded,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool? expanded;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: true,
      focusable: true,
      label: label,
      expanded: expanded,
      onTap: onPressed,
      excludeSemantics: true,
      child: IconButton(
        onPressed: onPressed,
        tooltip: label,
        iconSize: 18,
        padding: const EdgeInsets.all(15),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: Icon(icon, color: color),
      ),
    );
  }
}
