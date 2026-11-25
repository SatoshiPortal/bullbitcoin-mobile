import 'package:material_ui/material_ui.dart';

import '../buttons/bull_tool_button.dart';
import '../theme/bull_icon.dart';

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
          button(showingStatus, statusLabel, BullIcons.showChart, onStatus),
          const SizedBox(width: 8),
          button(
            !showingStatus,
            detailsLabel,
            BullIcons.receiptLong,
            onDetails,
          ),
        ],
      ),
    );
  }
}
