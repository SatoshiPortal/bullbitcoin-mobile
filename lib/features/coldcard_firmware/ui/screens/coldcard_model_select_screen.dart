import 'package:bb_mobile/core/coldcard_firmware/domain/entities/coldcard_device.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/tiles/bordered_tappable_tile.dart';
import 'package:bb_mobile/features/coldcard_firmware/ui/coldcard_firmware_router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ColdcardModelSelectScreen extends StatelessWidget {
  const ColdcardModelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.coldcardUpdateTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              const Gap(16),
              BBText(
                context.loc.coldcardUpdateSelectModelDescription,
                style: context.font.bodyLarge,
                color: context.appColors.textMuted,
                maxLines: 3,
              ),
              const Gap(24),
              for (final device in ColdcardDevice.values) ...[
                _ColdcardModelCard(device: device),
                const Gap(16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ColdcardModelCard extends StatelessWidget {
  const _ColdcardModelCard({required this.device});

  final ColdcardDevice device;

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (device) {
      ColdcardDevice.q => context.loc.coldcardUpdateModelQSubtitle,
      ColdcardDevice.mk4 => context.loc.coldcardUpdateModelMk4Subtitle,
    };
    final monogram = switch (device) {
      ColdcardDevice.q => 'Q',
      ColdcardDevice.mk4 => 'Mk4',
    };

    return BorderedTappableTile(
      padding: const EdgeInsets.all(16),
      onTap: () => context.pushNamed(
        ColdcardFirmwareRoute.coldcardUpdateDevice.name,
        extra: device,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: .center,
            decoration: BoxDecoration(
              color: context.appColors.secondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: BBText(
              monogram,
              style: context.font.titleMedium,
              color: context.appColors.onSecondary,
            ),
          ),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                BBText(device.displayName, style: context.font.headlineSmall),
                const Gap(4),
                BBText(
                  subtitle,
                  style: context.font.bodySmall,
                  color: context.appColors.textMuted,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const Gap(8),
          Icon(Icons.chevron_right, color: context.appColors.textMuted),
        ],
      ),
    );
  }
}
