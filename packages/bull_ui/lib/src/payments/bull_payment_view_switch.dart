import 'package:material_ui/material_ui.dart';

import '../buttons/bull_tool_button.dart';
import '../theme/bull_icon.dart';
import '../theme/bull_theme.dart';
import '../theme/bull_tokens.dart';
import '../theme/payment_animation_palette.dart';

/// Status | Details: switches between the two views of a payment. The shown
/// view's button is primary. Labels are supplied by the owner.
class BullPaymentViewSwitch extends StatelessWidget {
  final bool showingStatus;
  final String statusLabel;
  final String detailsLabel;

  /// Accessible name of the group of two buttons.
  final String semanticsLabel;
  final VoidCallback onStatus;
  final VoidCallback onDetails;

  const BullPaymentViewSwitch({
    super.key,
    required this.showingStatus,
    required this.statusLabel,
    required this.detailsLabel,
    required this.semanticsLabel,
    required this.onStatus,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    Widget button(
      bool selected,
      String label,
      IconData icon,
      VoidCallback onPressed,
    ) {
      // One node per view: the selected state belongs to the button itself.
      return MergeSemantics(
        child: Semantics(
          selected: selected,
          button: true,
          child: BullToolButton(
            label: label,
            icon: icon,
            primary: selected,
            onPressed: onPressed,
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticsLabel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: button(
              showingStatus,
              statusLabel,
              BullIcons.showChart,
              onStatus,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: button(
              !showingStatus,
              detailsLabel,
              BullIcons.receiptLong,
              onDetails,
            ),
          ),
        ],
      ),
    );
  }
}

/// The two views of a payment above one fixed [switcher] strip: the switch
/// sits at the same place whichever view is shown. The strip takes the
/// bottom safe area, so the views lay out without it. With no [switcher],
/// [views] fills the space alone.
class BullPaymentViews extends StatelessWidget {
  final bool showingStatus;
  final Widget views;
  final Widget? switcher;

  const BullPaymentViews({
    super.key,
    required this.showingStatus,
    required this.views,
    this.switcher,
  });

  @override
  Widget build(BuildContext context) {
    final switcher = this.switcher;
    if (switcher == null) return views;
    final palette =
        Theme.of(context).extension<PaymentAnimationPalette>() ??
        PaymentAnimationPalette.standard;
    return Column(
      children: [
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: views,
          ),
        ),
        // Blended into the view shown, so it reads as part of it.
        ColoredBox(
          color: showingStatus ? palette.background : context.bull.background,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                BullSpacing.md,
                BullSpacing.xs,
                BullSpacing.md,
                BullSpacing.md,
              ),
              child: Center(child: switcher),
            ),
          ),
        ),
      ],
    );
  }
}
