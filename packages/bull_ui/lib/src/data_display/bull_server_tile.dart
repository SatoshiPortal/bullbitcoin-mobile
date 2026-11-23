import 'package:bull_ui/src/data_display/bull_badge.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:material_ui/material_ui.dart';

/// A server row shared by the Electrum and Mempool settings: an optional drag
/// handle, the server title on its own line (long host names keep the full
/// width), the status line with the connection badge aligned to the right,
/// and an optional delete button.
///
/// Purely presentational: the caller supplies every label and colour.
class BullServerTile extends StatelessWidget {
  const BullServerTile({
    super.key,
    required this.title,
    required this.statusColor,
    required this.statusLabel,
    required this.badgeLabel,
    this.badgeIsWarning = false,
    this.showDragHandle = false,
    this.disabled = false,
    this.disabledLabel,
    this.onDelete,
    this.deleteTooltip,
  }) : assert(
         onDelete == null || deleteTooltip != null,
         'A delete button needs a translated tooltip',
       );

  /// Server name.
  final String title;

  /// Colour of the status dot.
  final Color statusColor;

  /// Status text next to the dot.
  final String statusLabel;

  /// Badge text, for example "Encrypted".
  final String badgeLabel;

  /// Draws the badge as a warning instead of a neutral one.
  final bool badgeIsWarning;

  /// Shows a drag handle before the title.
  final bool showDragHandle;

  /// Strikes the title through and dims the row.
  final bool disabled;

  /// Text shown while [disabled], for example "Not used".
  final String? disabledLabel;

  /// Delete callback; the delete button is hidden when null.
  final VoidCallback? onDelete;

  /// Tooltip and accessible name of the delete button.
  final String? deleteTooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final disabledText = disabledLabel;

    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(context.bullShapes.card),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            if (showDragHandle) ...[
              ExcludeSemantics(
                child: Icon(
                  Icons.drag_handle,
                  color: colors.onSurface.withValues(alpha: 0.5),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _breakAtSeparators(title),
                      semanticsLabel: title,
                      style: context.bullType.body.copyWith(
                        color: colors.onSurface,
                        decoration: disabled
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: statusColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  statusLabel,
                                  style: context.bullType.label.copyWith(
                                    fontWeight: FontWeight.w400,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                              if (disabled && disabledText != null) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    disabledText,
                                    style: context.bullType.label.copyWith(
                                      fontWeight: FontWeight.w400,
                                      color: colors.onSurface.withValues(
                                        alpha: 0.6,
                                      ),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        BullBadge(
                          label: badgeLabel,
                          background: badgeIsWarning
                              ? colors.warningContainer
                              : colors.surfaceContainerHighest,
                          foreground: colors.onSurface,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.delete_outline, color: colors.error),
                tooltip: deleteTooltip,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: onDelete,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Lets a long host name wrap after `.`, `:` or `-` instead of inside a
  /// word, by inserting zero-width spaces; the semantics keep the raw title.
  static String _breakAtSeparators(String value) =>
      value.replaceAllMapped(RegExp('[.:-]'), (m) => '${m[0]}\u200B');
}
