import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart'
    show ExchangeRoute;
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullBottomSheet,
        BullButton,
        BullShapesX,
        BullText,
        BullTextRole,
        BullTypographyX;

class NotLoggedInBottomSheet extends StatelessWidget {
  const NotLoggedInBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return BullBottomSheet.show(
      context: context,
      child: const NotLoggedInBottomSheet(),
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
              context.loc.notLoggedInMessage,
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
                context.goNamed(ExchangeRoute.exchangeHome.name);
              },
            ),
          ],
        ),
      ),
    );
  }
}
