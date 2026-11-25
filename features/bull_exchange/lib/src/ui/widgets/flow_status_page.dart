import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullScrollableColumn, BullTypographyX, Gap;
import 'package:material_ui/material_ui.dart';

/// One action of a [FlowStatusPage].
final class FlowAction {
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  const FlowAction(this.label, this.onPressed, {this.primary = true});
}

/// The page a flow shows for a step state that is waiting, failed or ended:
/// a title, an optional message, a spinner while [busy], and the exits the
/// state has. Every exit is an event of the flow.
///
/// The app bar's back is [onBack], never one implied by the navigator: a
/// flow's pages live in the flow's own navigator, whose first page can't pop,
/// and popping it would skip the flow machine. A state with no way back says
/// so with `onBack: null`.
class FlowStatusPage extends StatelessWidget {
  const FlowStatusPage({
    super.key,
    required this.title,
    required this.onBack,
    this.headline,
    this.message,
    this.busy = false,
    this.isError = false,
    this.actions = const [],
  });

  final String title;

  /// Sends the flow's back event; null shows no back.
  final VoidCallback? onBack;
  final String? headline;
  final String? message;
  final bool busy;
  final bool isError;
  final List<FlowAction> actions;

  @override
  Widget build(BuildContext context) {
    final headline = this.headline;
    final message = this.message;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: switch (onBack) {
          final onBack? => BackButton(onPressed: onBack),
          null => null,
        },
        title: Text(title),
      ),
      body: SafeArea(
        child: BullScrollableColumn(
          padding: const EdgeInsets.all(24),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(24),
            if (busy) ...[
              const Center(child: CircularProgressIndicator()),
              const Gap(24),
            ],
            if (headline != null) ...[
              Text(
                headline,
                textAlign: TextAlign.center,
                style: context.bullType.subtitle.copyWith(
                  color: context.appColors.secondary,
                ),
              ),
              const Gap(12),
            ],
            if (message != null)
              Text(
                message,
                textAlign: TextAlign.center,
                style: context.bullType.body.copyWith(
                  color: isError
                      ? context.appColors.error
                      : context.appColors.onSurfaceVariant,
                ),
              ),
            const Spacer(),
            for (final action in actions) ...[
              action.primary
                  ? BullButton.primary(
                      label: action.label,
                      onPressed: action.onPressed,
                    )
                  : BullButton.secondary(
                      label: action.label,
                      onPressed: action.onPressed,
                    ),
              const Gap(12),
            ],
          ],
        ),
      ),
    );
  }
}
