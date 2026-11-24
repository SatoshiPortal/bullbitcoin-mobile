import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';

import '../presentation/ark_l10n.dart';

/// Ark attention entry: renewal that needs the user, or funds while Ark is
/// off. A renewal already under way shows as Pending in the activity list.
class ArkAttention extends StatelessWidget {
  final ArkSnapshot snapshot;
  final bool enabled;
  final VoidCallback onOpen;
  const ArkAttention({
    super.key,
    required this.snapshot,
    required this.enabled,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final message = switch (snapshot.renewal) {
      ArkRenewalStatus.due || ArkRenewalStatus.failed => l10n.renewalWarning,
      _ => !enabled && snapshot.hasFundsOrObligations ? l10n.offFunded : null,
    };
    if (message == null) return const SizedBox.shrink();
    // The app's warning card, as on its swap screens.
    return BullInfoCard(
      description: message,
      tagColor: context.bull.tertiary,
      bgColor: context.bull.warningContainer,
      onTap: onOpen,
    );
  }
}
