import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';

import '../presentation/ark_l10n.dart';
import 'ark_amount.dart';

/// Observation and navigation only. Foreground reviews recheck spending rules.
class ArkExitsScreen extends StatefulWidget {
  final ArkSnapshot snapshot;
  final VoidCallback onReviewExit;
  final VoidCallback? onRefresh;
  final VoidCallback onReviewProgress;
  final ValueChanged<List<String>> onReviewClaim;
  const ArkExitsScreen({
    super.key,
    required this.snapshot,
    required this.onReviewExit,
    this.onRefresh,
    required this.onReviewProgress,
    required this.onReviewClaim,
  });
  @override
  State<ArkExitsScreen> createState() => _ArkExitsScreenState();
}

class _ArkExitsScreenState extends State<ArkExitsScreen> {
  final Set<String> _expanded = {};

  @override
  void didUpdateWidget(ArkExitsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.account != widget.snapshot.account) {
      _expanded.clear();
    }
  }

  void _details(ArkAccountId account, String id) {
    if (!mounted ||
        widget.snapshot.account != account ||
        !widget.snapshot.exitDetails.any((exit) => exit.id == id)) {
      return;
    }
    setState(() {
      if (!_expanded.add(id)) _expanded.remove(id);
    });
  }

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
      backgroundColor: context.bull.background,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            BullSpacing.md,
            BullSpacing.xs,
            BullSpacing.md,
            BullSpacing.lg,
          ),
          child: BullButton.big(
            label: l10n.startEmergencyExit,
            onPressed: () => _review(account),
            disabled: !_current,
            bgColor: context.bull.surface,
            textColor: context.bull.primary,
            outlined: true,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BullSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BullTopBar(
                title: l10n.exits,
                titleWidget: BullText(l10n.exits, role: BullTextRole.subtitle),
                onBack: () => Navigator.pop(context),
              ),
              Container(
                padding: const EdgeInsets.all(BullSpacing.md),
                decoration: BoxDecoration(
                  color: context.bull.surface,
                  borderRadius: BorderRadius.circular(context.bullShapes.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        BullIcon(
                          BullIcons.warningAmber,
                          color: context.bull.primary,
                        ),
                        const Gap(BullSpacing.sm),
                        Expanded(
                          child: BullText(
                            l10n.emergencyOnlyTitle,
                            role: BullTextRole.subtitle,
                          ),
                        ),
                      ],
                    ),
                    const Gap(BullSpacing.sm),
                    BullText(
                      l10n.emergencyOnlyBody,
                      role: BullTextRole.body,
                      color: context.bull.textMuted,
                    ),
                    const Gap(BullSpacing.sm),
                    BullText(
                      l10n.emergencySendInstead,
                      role: BullTextRole.body,
                      color: context.bull.textMuted,
                    ),
                  ],
                ),
              ),
              const Gap(BullSpacing.md),
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
                Container(
                  padding: const EdgeInsets.all(BullSpacing.lg),
                  decoration: BoxDecoration(
                    color: context.bull.surface,
                    borderRadius: BorderRadius.circular(
                      context.bullShapes.card,
                    ),
                  ),
                  child: Column(
                    children: [
                      BullIcon(
                        BullIcons.arrowUpward,
                        color: context.bull.textMuted,
                      ),
                      const Gap(BullSpacing.sm),
                      BullText(
                        l10n.noEmergencyExits,
                        role: BullTextRole.subtitle,
                      ),
                      const Gap(BullSpacing.xs),
                      BullText(
                        l10n.noEmergencyExitsBody,
                        role: BullTextRole.body,
                        color: context.bull.textMuted,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              const Gap(BullSpacing.md),
              for (final exit in snapshot.exitDetails) ...[
                BullBorderedTile(
                  onTap: () => _details(account, exit.id),
                  backgroundColor: context.bull.surface,
                  child: Row(
                    children: [
                      Expanded(
                        child: BullText(
                          formatArkObservedSats(context, exit.amount),
                          role: BullTextRole.subtitle,
                        ),
                      ),
                      BullBadge(
                        label: _status(context, exit.status),
                        background: context.bull.transparent,
                        foreground: switch (exit.status) {
                          ArkExitStatus.failed => context.bull.error,
                          ArkExitStatus.pending ||
                          ArkExitStatus.claimable ||
                          ArkExitStatus.submitted => context.bull.warning,
                          _ => context.bull.textMuted,
                        },
                      ),
                      BullIcon(
                        BullIcons.chevronRight,
                        color: context.bull.textMuted,
                      ),
                    ],
                  ),
                ),
                if (_expanded.contains(exit.id))
                  BullDetailsTable(
                    items: [
                      BullDetailsTableItem(
                        label: l10n.id,
                        displayValue: exit.id,
                      ),
                      BullDetailsTableItem(
                        label: l10n.amount,
                        displayValue: formatArkObservedSats(
                          context,
                          exit.amount,
                          withUnit: false,
                        ),
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
              if (widget.onRefresh case final refresh?)
                _button(context, l10n.refresh, () {
                  if (mounted && widget.snapshot.account == account) refresh();
                }, disabled: false),
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

  String _status(BuildContext context, ArkExitStatus status) {
    final l10n = arkLocalizationsOf(context);
    return switch (status) {
      ArkExitStatus.unknown => l10n.exitStatusUnknown,
      ArkExitStatus.none => l10n.exitStatusNone,
      ArkExitStatus.pending => l10n.exitStatusPending,
      ArkExitStatus.claimable => l10n.exitStatusClaimable,
      ArkExitStatus.submitted => l10n.exitStatusSubmitted,
      ArkExitStatus.claimed => l10n.exitStatusClaimed,
      ArkExitStatus.failed => l10n.exitStatusFailed,
    };
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
