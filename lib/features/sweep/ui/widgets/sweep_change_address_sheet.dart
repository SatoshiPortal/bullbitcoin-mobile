import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bull_ui/bull_ui.dart';

/// Picker over the wallet's own unused change addresses.
///
/// Sweeping back to yourself is the common case, and typing a self-owned
/// address by hand invites a costly typo. Only never-used addresses are listed:
/// reusing one that already saw a payment links the two on-chain, which is the
/// leak coin control exists to avoid.
class SweepChangeAddressSheet extends StatelessWidget {
  const SweepChangeAddressSheet({
    super.key,
    required this.addresses,
    required this.onSelected,
  });

  final List<WalletAddress> addresses;
  final ValueChanged<WalletAddress> onSelected;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final colors = context.bull;

    return BullScrollableColumn(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          loc.sweepChangeAddressSheetTitle,
          style: context.bullText.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        const Gap(6),
        Text(
          loc.sweepChangeAddressSheetBody,
          style: context.bullText.bodySmall?.copyWith(color: colors.textMuted),
        ),
        const Gap(16),
        if (addresses.isEmpty)
          BullInfoBar(message: loc.sweepChangeAddressSheetEmpty)
        else
          for (final address in addresses)
            _ChangeAddressRow(
              address: address,
              onTap: () => onSelected(address),
            ),
      ],
    );
  }
}

class _ChangeAddressRow extends StatelessWidget {
  const _ChangeAddressRow({required this.address, required this.onTap});

  final WalletAddress address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(BullRadius.xs),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.loc.sweepChangeAddressIndex(address.index),
                    style: context.bullText.labelMedium?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                  const Gap(2),
                  BullAddressText(address: address.address),
                ],
              ),
            ),
            BullIcon(BullIcons.chevronRight, size: 18, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}
