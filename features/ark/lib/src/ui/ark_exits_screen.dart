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
    if (!identical(oldWidget.snapshot, widget.snapshot)) {
      _expanded.clear();
    }
  }

  void _details(ArkExitsScreen rendered, String id) {
    if (!mounted ||
        !identical(rendered, widget) ||
        ModalRoute.of(context)?.isCurrent != true ||
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

  void _review(ArkExitsScreen rendered, {bool progress = false}) {
    if (!mounted ||
        !identical(rendered, widget) ||
        !_current ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    if (progress) {
      if (_hasDetails) widget.onReviewProgress();
    } else {
      widget.onReviewExit();
    }
  }

  void _claim(ArkExitsScreen rendered, String id) {
    if (!mounted ||
        !identical(rendered, widget) ||
        !_claimable(id) ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    widget.onReviewClaim(List.unmodifiable([id]));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final snapshot = widget.snapshot;
    final rendered = widget;
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
            onPressed: () => _review(rendered),
            disabled: !_current,
            bgColor: context.bull.secondary,
            textColor: context.bull.onSecondary,
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
              BullText(l10n.exitYourExits, role: BullTextRole.subtitle),
              const Gap(BullSpacing.md),
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
                  onTap: () => _details(rendered, exit.id),
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
                if (_expanded.contains(exit.id)) ...[
                  _timeline(context, exit),
                  BullDetailsTable(
                    flat: true,
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
                ],
                const Gap(BullSpacing.xs),
                if (exit.status == ArkExitStatus.claimable)
                  _button(
                    context,
                    l10n.review,
                    () => _claim(rendered, exit.id),
                    disabled: !_claimable(exit.id),
                  ),
              ],
              if (widget.onRefresh case final refresh?)
                _button(context, l10n.refresh, () {
                  if (mounted &&
                      identical(rendered, widget) &&
                      identical(widget.onRefresh, refresh) &&
                      ModalRoute.of(context)?.isCurrent == true) {
                    refresh();
                  }
                }, disabled: false),
              if (_hasDetails) BullInfoBar(message: l10n.foregroundExit),
              _button(
                context,
                l10n.review,
                () => _review(rendered, progress: true),
                disabled: !_current || !_hasDetails,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeline(BuildContext context, ArkExit exit) {
    final l10n = arkLocalizationsOf(context);
    final phase = exit.phase;
    if (phase == ArkExitPhase.failed || phase == ArkExitPhase.canceled) {
      return BullInfoBar(
        message: phase == ArkExitPhase.canceled
            ? l10n.exitCanceled
            : _status(context, ArkExitStatus.failed),
        tone: BullInfoTone.warning,
      );
    }
    final unrolled = const {
      ArkExitPhase.delay,
      ArkExitPhase.claimable,
      ArkExitPhase.claiming,
      ArkExitPhase.claimed,
    }.contains(phase);
    final delayed = const {
      ArkExitPhase.claimable,
      ArkExitPhase.claiming,
      ArkExitPhase.claimed,
    }.contains(phase);
    final claimed =
        phase == ArkExitPhase.claimed &&
        exit.status == ArkExitStatus.claimed &&
        exit.claimTxid?.isNotEmpty == true;
    Widget step(String title, bool complete, {String? detail}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: BullSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BullIcon(
            complete ? BullIcons.check : BullIcons.schedule,
            color: complete ? context.bull.text : context.bull.textMuted,
          ),
          const Gap(BullSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BullText(title, role: BullTextRole.body),
                if (detail != null)
                  BullText(
                    detail,
                    role: BullTextRole.label,
                    color: context.bull.textMuted,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    final tip = widget.snapshot.tipHeight;
    final height = exit.claimableHeight;
    final remaining =
        phase == ArkExitPhase.delay &&
            tip != null &&
            height != null &&
            !widget.snapshot.stale
        ? (height > tip ? height - tip : 0)
        : null;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: BullSpacing.sm),
      padding: const EdgeInsets.all(BullSpacing.md),
      decoration: BoxDecoration(
        color: context.bull.surface,
        borderRadius: BorderRadius.circular(context.bullShapes.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BullText(l10n.exitDetailsTitle, role: BullTextRole.subtitle),
          step(
            l10n.emergencyExitStarted,
            phase != null &&
                phase != ArkExitPhase.failed &&
                phase != ArkExitPhase.canceled,
          ),
          step(
            l10n.exitUnrolling,
            unrolled,
            detail: phase == null ? l10n.unknown : null,
          ),
          step(
            l10n.exitDelay,
            delayed,
            detail: remaining == null
                ? null
                : l10n.exitBlocksRemaining(remaining.toString()),
          ),
          if (phase == ArkExitPhase.delay && exit.confirmedHeight != null)
            BullText(
              l10n.exitConfirmedAtBlock(exit.confirmedHeight.toString()),
              role: BullTextRole.label,
              color: context.bull.textMuted,
            ),
          step(
            l10n.exitClaimAction,
            claimed,
            detail: claimed ? null : l10n.exitManualClaim,
          ),
        ],
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
      bgColor: context.bull.secondary,
      textColor: context.bull.onSecondary,
    ),
  );
}
