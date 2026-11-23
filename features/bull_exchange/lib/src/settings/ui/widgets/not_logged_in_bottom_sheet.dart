import '../../../exchange_l10n.dart';

import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullBottomSheet,
        BullButton,
        BullShapesX,
        BullText,
        BullTextRole,
        BullTypographyX;

class NotLoggedInBottomSheet extends StatelessWidget {
  final String message;
  final VoidCallback onSignIn;

  const NotLoggedInBottomSheet({
    required this.message,
    required this.onSignIn,
    super.key,
  });

  static Future<void> show(
    BuildContext context, {
    required String message,
    required VoidCallback onSignIn,
  }) {
    return BullBottomSheet.show(
      context: context,
      child: NotLoggedInBottomSheet(message: message, onSignIn: onSignIn),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: .min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(context.bullShapes.dot),
              ),
            ),
            const SizedBox(height: 24),
            Icon(
              Icons.account_circle_outlined,
              size: 48,
              color: context.appColors.primary,
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: BullText(
                context.loc.notLoggedInTitle,
                role: BullTextRole.subtitle,
                fontWeight: FontWeight.bold,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            BullText(
              message,
              style: context.bullType.body.copyWith(
                color: context.appColors.secondary.withValues(alpha: 0.7),
              ),
              textAlign: .center,
              maxLines: 3,
              overflow: .ellipsis,
            ),
            const SizedBox(height: 24),
            BullButton.secondary(
              label: context.loc.loginButton,
              onPressed: () {
                Navigator.of(context).pop();
                onSignIn();
              },
            ),
          ],
        ),
      ),
    );
  }
}
