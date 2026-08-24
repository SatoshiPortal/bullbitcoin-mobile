import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

/// The settings search entry point: a rounded bar at the top of the list.
///
/// Shaped after AOSP's `search_bar.xml`, which GrapheneOS ships: a card holding
/// a magnifier and a *static* label. It is a button, not a field — tapping it
/// opens the search screen instead of raising a keyboard here, so the label is a
/// [Text] and there is no controller behind it.
///
/// The icon is decorative and the label already names the action, so the whole
/// bar reports itself as a single button rather than as an icon plus a string.
class SettingsSearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const SettingsSearchBar({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = context.loc.settingsSearchHint;

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: context.appColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(Icons.search, color: context.appColors.onSurface),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
