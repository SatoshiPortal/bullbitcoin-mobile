import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';

import '../presentation/ark_l10n.dart';

/// Observation and navigation only. Foreground reviews recheck spending rules.
class ArkExitsScreen extends StatefulWidget {
  final ArkSnapshot snapshot;
  final VoidCallback onReviewExit;
  final VoidCallback onReviewProgress;
  final ValueChanged<List<String>> onReviewClaim;
  const ArkExitsScreen({
    super.key,
    required this.snapshot,
    required this.onReviewExit,
    required this.onReviewProgress,
    required this.onReviewClaim,
  });
  @override
  State<ArkExitsScreen> createState() => _ArkExitsScreenState();
}

class _ArkExitsScreenState extends State<ArkExitsScreen> {
  // The snapshot has no separate exit-freshness stamp. Never manufacture one
  // from recovery or VTXO completeness; stale observations remain read-only.
  bool get _current =>
      !widget.snapshot.stale &&
      widget.snapshot.tipHeight != null &&
      widget.snapshot.exits != ArkExitStatus.unknown &&
      widget.snapshot.exits != ArkExitStatus.failed;
  bool get _hasDetails => widget.snapshot.exitDetails.any(
    (e) =>
        e.id.isNotEmpty &&
        e.status != ArkExitStatus.unknown &&
        e.status != ArkExitStatus.failed,
  );
  bool _claimable(String id) {
    final rows = widget.snapshot.exitDetails.where((e) => e.id == id).toList();
    return _current &&
        id.isNotEmpty &&
        rows.length == 1 &&
        rows.single.status == ArkExitStatus.claimable;
  }

  void _review(ArkAccountId account, {bool progress = false}) {
    if (!mounted || widget.snapshot.account != account || !_current) return;
    if (progress) {
      if (_hasDetails) widget.onReviewProgress();
    } else {
      widget.onReviewExit();
    }
  }

  void _claim(ArkAccountId account, String id) {
    if (!mounted || widget.snapshot.account != account || !_claimable(id)) {
      return;
    }
    widget.onReviewClaim(List.unmodifiable([id]));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final snapshot = widget.snapshot;
    final account = snapshot.account;
    return BullScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BullSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BullTopBar(
                title: l10n.exits,
                onBack: () => Navigator.pop(context),
              ),
              BullInfoBar(
                message: l10n.foregroundExit,
                tone: BullInfoTone.warning,
              ),
              if (snapshot.stale) BullInfoBar(message: l10n.stale),
              if (snapshot.recovery != ArkRecoveryStatus.complete)
                BullInfoBar(message: l10n.recovery),
              if (!_current ||
                  (snapshot.exitDetails.isEmpty &&
                      snapshot.exits != ArkExitStatus.none))
                BullInfoBar(message: l10n.unknown),
              if (_current &&
                  snapshot.exitDetails.isEmpty &&
                  snapshot.exits == ArkExitStatus.none)
                BullText(l10n.empty, style: null),
              const Gap(BullSpacing.md),
              for (final exit in snapshot.exitDetails) ...[
                BullDetailsTable(
                  items: [
                    BullDetailsTableItem(label: l10n.id, displayValue: exit.id),
                    BullDetailsTableItem(
                      label: l10n.amount,
                      displayValue: exit.amount.value.toString(),
                    ),
                    BullDetailsTableItem(
                      label: l10n.state,
                      displayValue: switch (exit.status) {
                        ArkExitStatus.unknown => l10n.exitStatusUnknown,
                        ArkExitStatus.none => l10n.exitStatusNone,
                        ArkExitStatus.pending => l10n.exitStatusPending,
                        ArkExitStatus.claimable => l10n.exitStatusClaimable,
                        ArkExitStatus.submitted => l10n.exitStatusSubmitted,
                        ArkExitStatus.claimed => l10n.exitStatusClaimed,
                        ArkExitStatus.failed => l10n.exitStatusFailed,
                      },
                    ),
                    BullDetailsTableItem(
                      label: l10n.claimableHeight,
                      displayValue:
                          exit.claimableHeight?.toString() ?? l10n.unknown,
                    ),
                    BullDetailsTableItem(
                      label: l10n.claimTxid,
                      displayValue: switch (exit.claimTxid) {
                        final String txid when txid.isNotEmpty => txid,
                        _ => l10n.unknown,
                      },
                      copyValue: switch (exit.claimTxid) {
                        final String txid when txid.isNotEmpty => txid,
                        _ => null,
                      },
                      copiedMessage: l10n.copied,
                    ),
                  ],
                ),
                const Gap(BullSpacing.xs),
                if (exit.status == ArkExitStatus.claimable)
                  _button(
                    context,
                    l10n.review,
                    () => _claim(account, exit.id),
                    disabled: !_claimable(exit.id),
                  ),
              ],
              _button(
                context,
                l10n.exits,
                () => _review(account),
                disabled: !_current,
              ),
              _button(
                context,
                l10n.review,
                () => _review(account, progress: true),
                disabled: !_current || !_hasDetails,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _button(
    BuildContext context,
    String label,
    VoidCallback onPressed, {
    required bool disabled,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: BullSpacing.xs),
    child: BullButton.big(
      label: label,
      onPressed: onPressed,
      disabled: disabled,
      bgColor: context.bull.surface,
      textColor: context.bull.text,
      outlined: true,
    ),
  );
}
