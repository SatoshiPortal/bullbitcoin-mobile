import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Shared layout for the exchange flows' success screens (buy, sell, pay) so
/// they stay structurally aligned: a success icon, a headline, an optional
/// amount line and message, and a bottom action area.
///
/// Back navigation is intercepted; the flow can only be left through [onClose],
/// which is called both by the close button and by a back gesture.
class SuccessScreenScaffold extends StatelessWidget {
  const SuccessScreenScaffold({
    super.key,
    required this.title,
    required this.headline,
    required this.onClose,
    this.icon,
    this.amountLine,
    this.message,
    this.actions = const <Widget>[],
  });

  /// App bar title, usually the name of the flow.
  final String title;

  /// Headline under the icon, e.g. "Order completed!".
  final String headline;

  /// Leaves the flow. Called by the close button and by a back gesture.
  final VoidCallback onClose;

  /// Defaults to a large success check mark.
  final Widget? icon;

  /// Line under the headline, e.g. "You sold 100 000 sats for $50.00".
  final String? amountLine;

  /// Explanatory content under the amount line. Styled as centered body text
  /// unless the widget overrides it, so a plain [Text] is enough.
  final Widget? message;

  /// Pinned to the bottom of the screen, typically buttons.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        onClose();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(icon: const Icon(Icons.close), onPressed: onClose),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: .center,
                children: [
                  icon ??
                      Icon(
                        Icons.check_circle,
                        size: 100,
                        color: context.appColors.success,
                      ),
                  const Gap(20),
                  Text(
                    headline,
                    style: context.font.titleLarge,
                    textAlign: .center,
                  ),
                  if (amountLine != null) ...[
                    const Gap(8),
                    Text(
                      amountLine!,
                      style: context.font.bodyLarge,
                      textAlign: .center,
                    ),
                  ],
                  if (message != null) ...[
                    const Gap(10),
                    DefaultTextStyle.merge(
                      style: context.font.bodyMedium,
                      textAlign: .center,
                      child: message!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: actions.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(mainAxisSize: .min, children: actions),
                ),
              ),
      ),
    );
  }
}
