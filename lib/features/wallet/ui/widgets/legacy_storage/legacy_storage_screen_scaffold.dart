import 'package:bb_mobile/features/wallet/ui/widgets/legacy_storage/legacy_storage_badge.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/wizard_dots.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart';

class LegacyStorageScreenScaffold extends StatelessWidget {
  const LegacyStorageScreenScaffold({
    super.key,
    required this.badgeLabel,
    required this.title,
    required this.body,
    this.primaryButton,
    required this.secondaryButton,
    required this.dotIndex,
    this.belowButtons,
    this.dotCount = 2,
  });

  final String badgeLabel;
  final String title;
  final Widget body;
  final Widget? primaryButton;
  final Widget secondaryButton;
  final Widget? belowButtons;
  final int dotIndex;
  final int dotCount;

  @override
  Widget build(BuildContext context) {
    return BullPage(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'assets/logos/bb-logo-small.png',
              width: 26,
              height: 26,
            ),
          ),
          const Gap(10),
          Align(
            alignment: Alignment.centerLeft,
            child: LegacyStorageBadge(label: badgeLabel),
          ),
          const Gap(8),
          BullText(
            title,
            style: context.bullText.displaySmall?.copyWith(
              fontFamily: 'Bebas Neue',
              color: context.bull.onSurface,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const Gap(10),
          Expanded(child: SingleChildScrollView(child: body)),
          if (belowButtons != null) ...[const Gap(10), belowButtons!],
          const Gap(10),
          WizardDots(count: dotCount, index: dotIndex),
        ],
      ),
      bottomBar: BullBottomActionBar(
        actions: [?primaryButton, secondaryButton],
      ),
    );
  }
}
