import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

class NetworkSelector extends StatelessWidget {
  final MempoolServerNetwork selectedNetwork;
  final Function(MempoolServerNetwork) onNetworkChanged;

  const NetworkSelector({
    super.key,
    required this.selectedNetwork,
    required this.onNetworkChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _NetworkChip(
            label: context.loc.mempoolNetworkBitcoinMainnet,
            isSelected:
                selectedNetwork == MempoolServerNetwork.bitcoinMainnet,
            onTap: () =>
                onNetworkChanged(MempoolServerNetwork.bitcoinMainnet),
          ),
          const SizedBox(width: 8),
          _NetworkChip(
            label: context.loc.mempoolNetworkBitcoinTestnet,
            isSelected:
                selectedNetwork == MempoolServerNetwork.bitcoinTestnet,
            onTap: () =>
                onNetworkChanged(MempoolServerNetwork.bitcoinTestnet),
          ),
          const SizedBox(width: 8),
          _NetworkChip(
            label: context.loc.mempoolNetworkLiquidMainnet,
            isSelected: selectedNetwork == MempoolServerNetwork.liquidMainnet,
            onTap: () => onNetworkChanged(MempoolServerNetwork.liquidMainnet),
          ),
          const SizedBox(width: 8),
          _NetworkChip(
            label: context.loc.mempoolNetworkLiquidTestnet,
            isSelected: selectedNetwork == MempoolServerNetwork.liquidTestnet,
            onTap: () => onNetworkChanged(MempoolServerNetwork.liquidTestnet),
          ),
        ],
      ),
    );
  }
}

class _NetworkChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NetworkChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? context.appColors.primary
              : context.appColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(color: context.appColors.outline),
        ),
        child: Text(
          label,
          style: context.font.labelMedium?.copyWith(
            color: isSelected
                ? context.appColors.onPrimary
                : context.appColors.onSurface,
          ),
        ),
      ),
    );
  }
}
