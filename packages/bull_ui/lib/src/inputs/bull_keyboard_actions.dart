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

  /// Runs when Done on the accessory bar is tapped, before the keyboard
  /// closes, for a form that applies its value on Done.
  ///
  /// keyboard_actions runs the same dismissal for Done and for a tap outside
  /// the field, so with [onDone] set a tap outside no longer closes the
  /// keyboard: otherwise tapping Back or Close would apply the value too.
  final VoidCallback? onDone;

  const BullKeyboardActions({
    super.key,
    required this.child,
    required this.doneText,
    this.nextFocus = true,
    this.disableScroll = false,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final done = onDone;
    return KeyboardActions(
      onDismissed: done == null ? null : (_) => done(),
      dismissOnTapOutside: done == null,
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
