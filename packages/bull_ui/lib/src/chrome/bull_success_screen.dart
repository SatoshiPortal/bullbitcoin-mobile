import 'package:bull_ui/src/chrome/bull_scaffold.dart';
import 'package:bull_ui/src/chrome/bull_top_bar.dart';
import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';

/// Shared visual structure for a completed flow.
///
/// The caller owns all copy, navigation, business state, and actions.
class BullSuccessScreen extends StatelessWidget {
  const BullSuccessScreen({
    super.key,
    required this.title,
    required this.headline,
    required this.onClose,
    this.icon,
    this.amountLine,
    this.message,
    this.actions = const <Widget>[],
  });

  final String title;
  final String headline;
  final VoidCallback onClose;
  final Widget? icon;
  final String? amountLine;
  final Widget? message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.bull;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onClose();
      },
      child: BullScaffold(
        body: SafeArea(
          child: Column(
            children: [
              BullTopBar(title: title, onAction: onClose),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: BullSpacing.lg,
                      vertical: BullSpacing.md,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        icon ??
                            BullIcon(
                              BullIcons.checkCircle,
                              size: 100,
                              color: colors.success,
                            ),
                        const SizedBox(height: BullSpacing.lg),
                        Text(
                          headline,
                          style: textTheme.titleLarge?.copyWith(
                            color: colors.text,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (amountLine != null) ...[
                          const SizedBox(height: BullSpacing.xs),
                          Text(
                            amountLine!,
                            style: textTheme.bodyLarge?.copyWith(
                              color: colors.text,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (message != null) ...[
                          const SizedBox(height: BullSpacing.sm),
                          DefaultTextStyle.merge(
                            style: textTheme.bodyMedium?.copyWith(
                              color: colors.text,
                            ),
                            textAlign: TextAlign.center,
                            child: message!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: actions.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(BullSpacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: actions,
                  ),
                ),
              ),
      ),
    );
  }
}
