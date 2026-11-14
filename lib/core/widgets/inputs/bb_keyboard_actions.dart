import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:material_ui/material_ui.dart';

class BBKeyboardActions extends StatelessWidget {
  const BBKeyboardActions({
    super.key,
    required this.child,
    this.nextFocus = true,
    this.disableScroll = false,
  });

  final Widget child;
  final bool nextFocus;
  final bool disableScroll;

  @override
  Widget build(BuildContext context) {
    return KeyboardActions(
      enabled: Theme.of(context).platform == TargetPlatform.iOS,
      navigation: nextFocus ? KeyboardNavigation.auto : KeyboardNavigation.none,
      ensureVisible: !disableScroll,
      doneText: context.loc.doneButton,
      theme: KeyboardActionsThemeData(
        barColor: context.appColors.surface,
        foregroundColor: context.appColors.onSurface,
        doneTextStyle: context.font.headlineMedium,
      ),
      child: child,
    );
  }
}
