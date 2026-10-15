import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, Gap;
import 'package:flutter/material.dart';

/// Draws a secret only once screen-capture blocking is confirmed.
///
/// [protection] is the screen's `enableScreenPrivacy()` future. Until it
/// completes nothing is drawn; if it reports `false`, the secret stays hidden
/// behind a message and [onRetry], which should call `enableScreenPrivacy()`
/// again.
class ScreenPrivacyGate extends StatelessWidget {
  const ScreenPrivacyGate({
    super.key,
    required this.protection,
    required this.onRetry,
    required this.builder,
  });

  final Future<bool> protection;
  final VoidCallback onRetry;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: protection,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        if (snapshot.data ?? false) return builder(context);
        return Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BBText(
                    context.loc.screenPrivacyUnavailable,
                    textAlign: .center,
                    style: context.font.bodyLarge?.copyWith(
                      color: context.appColors.error,
                    ),
                  ),
                  const Gap(16),
                  BullButton.small(
                    label: context.loc.retry,
                    onPressed: onRetry,
                    bgColor: context.appColors.secondary,
                    textColor: context.appColors.onSecondary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
