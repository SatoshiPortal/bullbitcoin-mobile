import 'package:bull_ui/src/buttons/bull_button.dart';
import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/layout/gap.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Draws a secret only once screen-capture blocking is confirmed.
///
/// [protection] is the screen's `enableScreenPrivacy()` future. Until it
/// completes nothing is drawn; if it reports `false`, the secret stays hidden
/// behind a message and [onRetry], which should call `enableScreenPrivacy()`
/// again.
class BullScreenPrivacyGate extends StatelessWidget {
  const BullScreenPrivacyGate({
    super.key,
    required this.protection,
    required this.unavailableMessage,
    required this.retryLabel,
    required this.onRetry,
    required this.builder,
    this.unavailableBuilder,
  });

  final Future<bool> protection;
  final String unavailableMessage;
  final String retryLabel;
  final VoidCallback onRetry;
  final WidgetBuilder builder;

  /// Inline failure content for hosts such as unbounded scrollable sections.
  /// When omitted, the gate shows its full-screen message and retry action.
  final WidgetBuilder? unavailableBuilder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: protection,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        if (snapshot.data ?? false) return builder(context);
        final unavailable = unavailableBuilder;
        if (unavailable != null) return unavailable(context);
        return Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: BullSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BullText(
                    unavailableMessage,
                    textAlign: .center,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: context.bull.error),
                  ),
                  const Gap(BullSpacing.md),
                  BullButton.small(
                    label: retryLabel,
                    onPressed: onRetry,
                    bgColor: context.bull.secondary,
                    textColor: context.bull.onSecondary,
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
