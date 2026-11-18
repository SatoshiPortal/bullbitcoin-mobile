import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';

import '../presentation/ark_l10n.dart';

/// Shared Home, Wallet settings and Ark attention entry. A delegated round is
/// deliberately still attention; only observed replacement can clear it.
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
      ArkRenewalStatus.delegated => l10n.renewalDelegated,
      ArkRenewalStatus.due || ArkRenewalStatus.failed => l10n.renewalWarning,
      _ => !enabled && snapshot.hasFundsOrObligations ? l10n.offFunded : null,
    };
    if (message == null) return const SizedBox.shrink();
    return BullBorderedTile(
      onTap: onOpen,
      child: BullInfoBar(message: message, tone: BullInfoTone.warning),
    );
  }
}
