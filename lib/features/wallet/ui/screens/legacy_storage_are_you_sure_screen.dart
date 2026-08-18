import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/legacy_storage/legacy_storage_screen_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart';

class LegacyStorageAreYouSureScreen extends StatefulWidget {
  const LegacyStorageAreYouSureScreen({
    super.key,
    required this.onBackupNow,
    required this.onConfirmContinue,
  });

  final VoidCallback onBackupNow;
  final VoidCallback onConfirmContinue;

  @override
  State<LegacyStorageAreYouSureScreen> createState() =>
      _LegacyStorageAreYouSureScreenState();
}

class _LegacyStorageAreYouSureScreenState
    extends State<LegacyStorageAreYouSureScreen> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final bodyTextStyle = context.bullText.bodyMedium?.copyWith(
      color: context.bull.onSurface,
      height: 1.35,
    );

    return LegacyStorageScreenScaffold(
      badgeLabel: loc.legacyStorageBadgeConfirm,
      title: loc.legacyStorageAreYouSureTitle,
      dotIndex: 1,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BullText(
            loc.legacyStorageAreYouSureParagraphOne,
            style: bodyTextStyle,
          ),
          const Gap(16),
          BullText(
            loc.legacyStorageAreYouSureParagraphTwo,
            style: bodyTextStyle,
          ),
        ],
      ),
      primaryButton: BullButton.primary(
        label: loc.legacyStorageBackupNowButton,
        onPressed: widget.onBackupNow,
      ),
      secondaryButton: BullButton.secondary(
        label: loc.legacyStorageContinueWithoutBackupButton,
        onPressed: widget.onConfirmContinue,
        disabled: !_accepted,
      ),
      belowButtons: _AcceptRisksRow(
        value: _accepted,
        onChanged: (v) => setState(() => _accepted = v ?? false),
        label: loc.legacyStorageAcceptRisksCheckbox,
      ),
    );
  }
}

class _AcceptRisksRow extends StatelessWidget {
  const _AcceptRisksRow({
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: context.bull.primary,
              side: BorderSide(color: context.bull.primary, width: 2),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const Gap(12),
          Expanded(
            child: BullText(
              label,
              style: context.bullText.bodyMedium?.copyWith(
                color: context.bull.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
