import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/bull_theme.dart';
import '../theme/bull_typography.dart';

/// Adds a themed iOS keyboard accessory to the fields in [child].
class BullKeyboardActions extends StatelessWidget {
  final Widget child;
  final String doneText;
  final bool nextFocus;
  final bool disableScroll;

  const BullKeyboardActions({
    super.key,
    required this.child,
    required this.doneText,
    this.nextFocus = true,
    this.disableScroll = false,
  });

  @override
  Widget build(BuildContext context) {
    return KeyboardActions(
      enabled: Theme.of(context).platform == TargetPlatform.iOS,
      navigation: nextFocus ? KeyboardNavigation.auto : KeyboardNavigation.none,
      ensureVisible: !disableScroll,
      doneText: doneText,
      theme: KeyboardActionsThemeData(
        barColor: context.bull.surface,
        foregroundColor: context.bull.onSurface,
        doneTextStyle: context.bullType.subtitle.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      child: child,
    );
  }
}
