import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// One destination or action of a [BullSideNav].
class BullSideNavItem {
  const BullSideNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
}

/// The navigation column on the left of a desktop window.
///
/// It keeps the same dark surface in the light and the dark theme, so the
/// brand colour of the selected destination reads the same in both.
class BullSideNav extends StatelessWidget {
  const BullSideNav({
    super.key,
    required this.items,
    this.header,
    this.footerItems = const [],
    this.width = 232,
  });

  /// Shown above the destinations, typically the logo.
  final Widget? header;

  /// The main destinations, top to bottom.
  final List<BullSideNavItem> items;

  /// Secondary entries pinned to the bottom of the column.
  final List<BullSideNavItem> footerItems;

  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return SizedBox(
      width: width,
      child: Material(
        color: colors.secondaryFixed,
        child: SafeArea(
          right: false,
          child: Padding(
            padding: const EdgeInsets.all(BullSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (header case final header?)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: BullSpacing.xs,
                      top: BullSpacing.xs,
                      bottom: BullSpacing.lg,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: header,
                    ),
                  ),
                for (final item in items) _Entry(item),
                const Spacer(),
                for (final item in footerItems) _Entry(item),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry(this.item);

  final BullSideNavItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final radius = BorderRadius.circular(context.bullShapes.button);
    final foreground = item.selected
        ? colors.onPrimary
        : colors.onSecondaryFixed.withValues(alpha: 0.72);
    return Padding(
      padding: const EdgeInsets.only(bottom: BullSpacing.xxs),
      child: Material(
        color: item.selected ? colors.primary : colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: radius,
          hoverColor: colors.onSecondaryFixed.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BullSpacing.sm,
              vertical: BullSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(item.icon, size: 20, color: foreground),
                const SizedBox(width: BullSpacing.sm),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: foreground,
                      fontWeight: item.selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
