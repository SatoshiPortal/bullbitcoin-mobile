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
        keyboardActionsPlatform: KeyboardActionsPlatform.IOS,
        keyboardBarColor: context.appColors.surface,
        keyboardSeparatorColor: context.appColors.border,
        nextFocus: nextFocus,
        actions: focusNodes
            .map(
              (node) => KeyboardActionsItem(
                focusNode: node,
                toolbarButtons: [
                  (focusNode) => InkWell(
                    onTap: focusNode.unfocus,
                    child: SizedBox(
                      height: 48,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Align(
                          alignment: Alignment.center,
                          child: Text(
                            'Done',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: context.appColors.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
      child: child,
    );
  }
}
