import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:keyboard_actions/keyboard_actions.dart';

class BBKeyboardActions extends StatelessWidget {
  const BBKeyboardActions({
    super.key,
    required this.focusNodes,
    required this.child,
    this.isDialog = false,
    this.nextFocus = true,
    this.disableScroll = false,
  });

  final List<FocusNode> focusNodes;
  final Widget child;
  final bool isDialog;
  final bool nextFocus;
  final bool disableScroll;

  @override
  Widget build(BuildContext context) {
    return KeyboardActions(
      isDialog: isDialog,
      disableScroll: disableScroll,
      tapOutsideBehavior: TapOutsideBehavior.translucentDismiss,
      config: KeyboardActionsConfig(
        keyboardActionsPlatform: KeyboardActionsPlatform.ALL,
        keyboardBarColor: context.appColors.surface,
        keyboardSeparatorColor: context.appColors.border,
        nextFocus: nextFocus,
        actions: focusNodes
            .map((node) => KeyboardActionsItem(focusNode: node))
            .toList(),
      ),
      child: child,
    );
  }
}
