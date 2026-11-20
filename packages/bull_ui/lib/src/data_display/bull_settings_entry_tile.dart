import 'package:material_ui/material_ui.dart';

import '../theme/bull_theme.dart';
import '../theme/bull_tokens.dart';
import '../theme/bull_typography.dart';

/// A full-width advanced-settings entry with an optional trailing summary.
/// The title and summary share one named button; the icons are decorative.
class BullSettingsEntryTile extends StatelessWidget {
  const BullSettingsEntryTile({
    super.key,
    required this.label,
    required this.onPressed,
    this.summary,
  });

  final String label;
  final String? summary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    focusable: onPressed != null,
    label: label,
    value: summary,
    onTap: onPressed,
    excludeSemantics: true,
    child: Material(
      color: context.bull.transparent,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: BullSpacing.xs),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: context.bull.border),
              bottom: BorderSide(color: context.bull.border),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Icon(
                  Icons.tune,
                  size: BullSpacing.lg,
                  color: context.bull.text,
                ),
                const SizedBox(width: BullSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: context.bullType.body.copyWith(
                      color: context.bull.text,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                if (summary case final text?) ...[
                  const SizedBox(width: BullSpacing.xs),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.35,
                    ),
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: context.bullType.label.copyWith(
                        color: context.bull.textMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: BullSpacing.xs),
                Icon(
                  Icons.chevron_right,
                  size: BullSpacing.lg,
                  color: context.bull.text,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
