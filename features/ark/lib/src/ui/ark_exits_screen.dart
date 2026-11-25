import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart'
    show IndexedStack, StackFit, TickerMode;
import 'package:primitives/primitives.dart';

import '../domain/ark_exit_candidates.dart';

import '../../generated/l10n/ark_localizations.dart';
import '../presentation/ark_l10n.dart';
import 'ark_amount.dart';
import 'ark_short_id.dart';
import 'ark_exit_steps.dart';
import 'ark_exit_animation_policy.dart';

/// Observation and navigation only. Foreground reviews recheck spending rules.
class ArkExitsScreen extends StatefulWidget {
  final ArkSnapshot snapshot;
  final VoidCallback onReviewExit;
  final VoidCallback? onRefresh;
  final VoidCallback? onSendOnChain;

  /// How much the Secure Bitcoin wallet must receive before started exits
  /// can pay their next fees; null when they are not waiting for it.
  final Sats? waitingForFunds;

  /// Whether payment animations are on. Null: always on.
  final Future<bool> Function()? readPaymentAnimations;

  const ArkExitsScreen({
    super.key,
    required this.snapshot,
    required this.onReviewExit,
    this.onRefresh,
    this.onSendOnChain,
    this.waitingForFunds,
    this.readPaymentAnimations,
  });

  @override
  State<ArkExitsScreen> createState() => _ArkExitsScreenState();
}

class _ArkExitsScreenState extends State<ArkExitsScreen> {
  String? _selected;

  // Null until the preference is read: the details show meanwhile, so the
  // animation never flashes against a stored "off".
  bool? _animations;

  // The exit's details, shown in place of its payment animation.
  bool _showDetails = false;

  Future<void> _readAnimations() async {
    final read = widget.readPaymentAnimations;
    if (read == null) {
      _animations = true;
      return;
    }
    bool value;
    try {
      value = await read();
    } on Object {
      value = true;
    }
    if (mounted) setState(() => _animations = value);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_readAnimations());
  }

  @override
  void didUpdateWidget(ArkExitsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.account != widget.snapshot.account) {
      _selected = null;
    }
  }

  /// The detail view only opens for one exact, currently observed row.
  ArkExit? get _detail {
    final id = _selected;
    if (id == null) return null;
    final rows = _exits.where((e) => e.id == id).toList();
    return rows.length == 1 ? rows.single : null;
  }

  /// The exits as the user started them: VTXOs exited in one go are one
  /// exit, read as their least advanced member, with their total amount.
  List<ArkExit> get _exits => [for (final group in _groups) group.exit];

  /// How many VTXOs each shown exit holds, by its id.
  Map<String, int> get _counts => {
    for (final group in _groups) group.exit.id: group.count,
  };

  List<({ArkExit exit, int count})> get _groups {
    final starts = [
      for (final op in widget.snapshot.operations)
        if (op.kind == ArkOperationKind.emergencyExit &&
            op.actualIds.isNotEmpty)
          op,
    ];
    final members = <String, List<ArkExit>>{};
    for (final exit in _vtxoExits) {
      final start = starts.where((op) => op.actualIds.contains(exit.id));
      final key = start.isEmpty ? exit.id : start.first.id;
      (members[key] ??= []).add(exit);
    }
    return [
      for (final MapEntry(:key, :value) in members.entries)
        (
          exit: value.length == 1 ? value.single : _combine(key, value),
          count: value.length,
        ),
    ];
  }

  static const _progress = [
    ArkExitStatus.unknown,
    ArkExitStatus.pending,
    ArkExitStatus.claimable,
    ArkExitStatus.submitted,
    ArkExitStatus.claimed,
  ];

  /// One exit of several VTXOs: as far along as its slowest member that can
  /// still finish. A member that failed or vanished does not hold it back.
  static ArkExit _combine(String id, List<ArkExit> exits) {
    final live = exits.where((e) => _progress.contains(e.status)).toList();
    final status = live.isEmpty
        ? exits.first.status
        : live
              .map((e) => e.status)
              .reduce(
                (a, b) => _progress.indexOf(a) <= _progress.indexOf(b) ? a : b,
              );
    final heights = [for (final e in live) e.claimableHeight];
    return ArkExit(
      id: id,
      amount: Sats(exits.fold(BigInt.zero, (sum, e) => sum + e.amount.value)),
      status: status,
      // Claimable when the last of them is; unknown while any is unrolling.
      claimableHeight: heights.isEmpty || heights.contains(null)
          ? null
          : heights.nonNulls.reduce((a, b) => a > b ? a : b),
      claimTxid: exits.map((e) => e.claimTxid).nonNulls.firstOrNull,
    );
  }

  /// Each VTXO's exit as the user should read it. A claimable one whose
  /// claim the app already sent is Claiming, before Bark sees it confirm.
  List<ArkExit> get _vtxoExits => [
    for (final exit in widget.snapshot.exitDetails)
      if (exit.status == ArkExitStatus.claimable &&
          widget.snapshot.operations.any(
            (op) =>
                op.kind == ArkOperationKind.claim &&
                (op.status == ArkOperationStatus.admitted ||
                    op.status == ArkOperationStatus.pending ||
                    op.status == ArkOperationStatus.succeeded) &&
                op.actualIds.contains(exit.id),
          ))
        ArkExit(
          id: exit.id,
          amount: exit.amount,
          status: ArkExitStatus.submitted,
          claimableHeight: exit.claimableHeight,
          claimTxid: exit.claimTxid,
        )
      else
        exit,
    ..._claimed,
  ];

  /// Exits that finished: Bark forgets an exit once it is claimed, but the
  /// app keeps each claim it made, so they stay listed as history.
  List<ArkExit> get _claimed {
    final snapshot = widget.snapshot;
    final live = {for (final exit in snapshot.exitDetails) exit.id};
    return [
      for (final op in snapshot.operations.reversed)
        if (op.kind == ArkOperationKind.claim &&
            op.status == ArkOperationStatus.succeeded)
          if (op.claimRecovery case final recovery?)
            for (final id in op.actualIds)
              if (!live.contains(id))
                ArkExit(
                  id: id,
                  amount: switch (snapshot.vtxos.where((v) => v.id == id)) {
                    final found when found.isNotEmpty => found.first.amount,
                    // Only the claim's own total is known for this VTXO.
                    _ when op.actualIds.length == 1 => recovery.net,
                    _ => Sats.zero,
                  },
                  status: ArkExitStatus.claimed,
                  claimTxid: recovery.txid,
                ),
    ];
  }

  void _details(ArkAccountId account, String id) {
    if (!mounted ||
        widget.snapshot.account != account ||
        // A shown exit: one VTXO's, or a group's started together.
        !_exits.any((exit) => exit.id == id)) {
      return;
    }
    setState(() {
      _selected = id;
      _showDetails = false;
    });
  }

  void _closeDetails() {
    if (mounted) {
      setState(() {
        _selected = null;
        _showDetails = false;
      });
    }
  }

  // A stale wallet can only open review for an individually priced board.
  bool get _current =>
      widget.snapshot.tipHeight != null &&
      widget.snapshot.exits != ArkExitStatus.unknown &&
      widget.snapshot.exits != ArkExitStatus.failed &&
      (!widget.snapshot.stale || arkExitCandidates(widget.snapshot).isNotEmpty);
  void _review(ArkAccountId account) {
    if (!mounted || widget.snapshot.account != account || !_current) return;
    widget.onReviewExit();
  }

  void _refresh(ArkAccountId account) {
    final refresh = widget.onRefresh;
    if (mounted && widget.snapshot.account == account && refresh != null) {
      refresh();
    }
  }

  void _sendOnChain(ArkAccountId account) {
    final send = widget.onSendOnChain;
    if (mounted && widget.snapshot.account == account && send != null) send();
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final phase = detail == null ? null : arkExitAnimationPhase(detail.status);
    // The animation replaces the page only for an exit that has one, once
    // the preference is known to be on.
    final animated = detail != null && phase != null && _animations == true;
    final Widget body;
    if (animated) {
      final showingStatus = !_showDetails;
      if (showingStatus) _statusBuilt = true;
      final switcher = _switcher(context, showingStatus);
      body = IndexedStack(
        sizing: StackFit.expand,
        index: showingStatus ? 0 : 1,
        children: [
          // A hidden view must not tick: its scene stops animating.
          TickerMode(
            enabled: showingStatus,
            child: !_statusBuilt
                ? const SizedBox.shrink()
                : _status(context, detail, phase, switcher),
          ),
          TickerMode(
            enabled: !showingStatus,
            child: _page(context, switcher: switcher),
          ),
        ],
      );
    } else {
      _statusBuilt = false;
      body = _page(context);
    }
    // The one back handler, for both views.
    return PopScope(
      canPop: detail == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeDetails();
      },
      child: body,
    );
  }

  bool _statusBuilt = false;

  Widget _switcher(BuildContext context, bool showingStatus) {
    final l10n = arkLocalizationsOf(context);
    return BullPaymentViewSwitch(
      showingStatus: showingStatus,
      statusLabel: l10n.exitViewStatus,
      detailsLabel: l10n.exitViewDetails,
      semanticsLabel: l10n.exitViewsLabel,
      onStatus: () {
        if (mounted) setState(() => _showDetails = false);
      },
      onDetails: () {
        if (mounted) setState(() => _showDetails = true);
      },
    );
  }

  Widget _status(
    BuildContext context,
    ArkExit exit,
    BullPaymentPhase phase,
    Widget switcher,
  ) {
    final l10n = arkLocalizationsOf(context);
    final label = arkExitStatusLabel(l10n, exit.status);
    return BullPaymentTransition(
      network: BullPaymentNetwork.arkExit,
      phase: phase,
      progress: arkExitAnimationProgress(
        exit,
        steps: [
          l10n.exitProgressUnrolling,
          l10n.exitStepDelay,
          l10n.exitStatusClaimable,
          l10n.exitProgressClaimBroadcast,
          l10n.exitProgressConfirmed,
        ],
      ),
      status: label,
      statusTag: label,
      bottom: switcher,
      onBack: _closeDetails,
      onDone: () {},
    );
  }

  Widget _page(BuildContext context, {Widget? switcher}) {
    final l10n = arkLocalizationsOf(context);
    final account = widget.snapshot.account;
    final detail = _detail;
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
          child: detail == null
              ? BullButton.big(
                  label: l10n.startEmergencyExit,
                  onPressed: () => _review(account),
                  disabled: !_current,
                  bgColor: context.bull.primary,
                  textColor: context.bull.onPrimary,
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (switcher != null) ...[
                      Center(child: switcher),
                      const Gap(BullSpacing.sm),
                    ],
                    _detailAction(context, account, detail),
                  ],
                ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BullSpacing.md),
              child: BullTopBar(
                title: l10n.exits,
                titleWidget: BullText(l10n.exits, role: BullTextRole.title),
                onBack: detail == null
                    ? () => Navigator.pop(context)
                    : _closeDetails,
              ),
            ),
            Expanded(
              // Pull to refresh, as on the app's wallets.
              child: BullRefreshIndicator(
                onRefresh: () async => _refresh(account),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    BullSpacing.md,
                    BullSpacing.zero,
                    BullSpacing.md,
                    BullSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (detail == null)
                        ..._home(context, account)
                      else
                        ..._detailBody(context, account, detail),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _home(BuildContext context, ArkAccountId account) {
    final l10n = arkLocalizationsOf(context);
    final snapshot = widget.snapshot;
    return [
      const _EmergencyOnlyCard(),
      const Gap(BullSpacing.sm),
      _ServerStatusBanner(
        // A fresh observation with server facts means the server answered.
        online: !snapshot.stale && snapshot.serverInfo != null,
        onSendOnChain: widget.onSendOnChain == null
            ? null
            : () => _sendOnChain(account),
      ),
      if (snapshot.stale) _Note(l10n.stale),
      if (snapshot.recovery != ArkRecoveryStatus.complete) _Note(l10n.recovery),
      ..._waiting(context),
      const Gap(BullSpacing.lg),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: BullSpacing.md),
        child: Semantics(
          header: true,
          child: BullText(
            l10n.exitListTitle,
            role: BullTextRole.label,
            fontWeight: FontWeight.w600,
            color: context.bull.textMuted,
          ),
        ),
      ),
      const Gap(BullSpacing.xs),
      // Offline or out of date, the list is what was last observed: it is
      // shown as it was, with the note above, never replaced by an error.
      // "No exits" only when that is what was observed: a summary that saw an
      // exit without its rows shows neither an empty state nor an error.
      if (_exits.isEmpty && snapshot.exits == ArkExitStatus.none)
        _StateCard(
          icon: BullIcons.arrowUpward,
          iconColor: context.bull.textMuted,
          title: l10n.noEmergencyExits,
          body: l10n.noEmergencyExitsBody,
        ),
      if (_exits.isNotEmpty) ...[
        Container(
          decoration: BoxDecoration(
            color: context.bull.surface,
            borderRadius: BorderRadius.circular(context.bullShapes.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, exit) in _exits.indexed) ...[
                if (index > 0)
                  Container(height: 1, color: context.bull.outlineVariant),
                _ExitRow(
                  exit: exit,
                  count: _counts[exit.id] ?? 1,
                  onTap: () => _details(account, exit.id),
                ),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  /// Started exits cannot pay their next fees until Secure Bitcoin has
  /// [ArkExitsScreen.waitingForFunds]: say how much to add.
  List<Widget> _waiting(BuildContext context) =>
      switch (widget.waitingForFunds) {
        final amount? => [
          const Gap(BullSpacing.sm),
          // Action needed: the app's warning card.
          BullInfoCard(
            description: arkLocalizationsOf(context)
                .exitWaitingForFunds(formatArkSats(context, amount)),
            tagColor: context.bull.tertiary,
            bgColor: context.bull.warningContainer,
          ),
        ],
        null => const [],
      };

  List<Widget> _detailBody(
    BuildContext context,
    ArkAccountId account,
    ArkExit exit,
  ) {
    final l10n = arkLocalizationsOf(context);
    final colors = context.bull;
    final steps = _steps(context, exit);
    return [
      if (exit.status == ArkExitStatus.pending) ...[
        ..._waiting(context),
        if (widget.waitingForFunds != null) const Gap(BullSpacing.md),
      ],
      Container(
        padding: const EdgeInsets.all(BullSpacing.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(context.bullShapes.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusBadge(status: exit.status),
            const Gap(BullSpacing.sm),
            BullText(
              formatArkObservedSats(context, exit.amount),
              role: BullTextRole.headline,
              fontWeight: FontWeight.w700,
            ),
            if (steps != null) ...[
              const Gap(BullSpacing.sm),
              _StepProgress(steps: steps),
            ],
          ],
        ),
      ),
      const Gap(BullSpacing.md),
      if (steps == null)
        // The app's error card, as on its exchange screens.
        BullInfoCard(
          description: exit.status == ArkExitStatus.failed
              ? l10n.exitDetailFailed
              : l10n.exitDetailUnknown,
          tagColor: context.bull.error,
          bgColor: context.bull.errorContainer,
        )
      else
        ArkExitSteps(steps: steps),
      if (widget.snapshot.stale) _Note(l10n.stale),
      // The claim transaction is the one fact the steps can't show.
      if (exit.claimTxid case final String txid when txid.isNotEmpty) ...[
        const Gap(BullSpacing.md),
        BullDetailsTable(
          items: [
            BullDetailsTableItem(
              label: l10n.claimTxid,
              displayValue: txid,
              copyValue: txid,
              copiedMessage: l10n.copied,
              displayWidget: BullText(
                arkShortId(txid),
                role: BullTextRole.body,
                fontWeight: FontWeight.w500,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ],
    ];
  }

  /// Stages derived only from the observed status and heights. Unknown and
  /// failed exits get no invented stage.
  List<ArkExitStep>? _steps(BuildContext context, ArkExit exit) {
    final l10n = arkLocalizationsOf(context);
    final status = exit.status;
    if (status == ArkExitStatus.unknown ||
        status == ArkExitStatus.failed ||
        status == ArkExitStatus.none) {
      return null;
    }
    final pending = status == ArkExitStatus.pending;
    final height = exit.claimableHeight;
    // Bark knows the claimable height only once every exit transaction has
    // confirmed: a pending exit with one is waiting out its delay.
    final unrolling = pending && height == null;
    final delaying = pending && height != null;
    final tip = widget.snapshot.tipHeight;
    final delayDetail = !pending
        ? l10n.exitStepDelayDone
        : height == null
        ? l10n.exitStepDelayUnknown
        : tip != null && height > tip && !widget.snapshot.stale
        ? l10n.exitStepDelayBlocksLeft(height - tip)
        : l10n.exitStepDelayWaiting;
    return [
      ArkExitStep(
        title: l10n.exitStepStarted,
        detail: l10n.exitStepStartedDetail,
        state: ArkExitStepState.done,
      ),
      ArkExitStep(
        title: l10n.exitStepUnrolling,
        detail: unrolling
            ? l10n.exitStepUnrollingPending
            : l10n.exitStepUnrollingDone,
        state: unrolling ? ArkExitStepState.current : ArkExitStepState.done,
      ),
      ArkExitStep(
        title: l10n.exitStepDelay,
        detail: delayDetail,
        state: switch ((unrolling, delaying)) {
          (true, _) => ArkExitStepState.upcoming,
          (_, true) => ArkExitStepState.current,
          _ => ArkExitStepState.done,
        },
      ),
      ArkExitStep(
        title: l10n.exitStepClaim,
        detail: switch (status) {
          ArkExitStatus.claimable => l10n.exitStepClaimReady,
          ArkExitStatus.submitted => l10n.exitStepClaimSubmitted,
          ArkExitStatus.claimed => l10n.exitStepClaimed,
          _ => l10n.exitStepClaimUpcoming,
        },
        state: switch (status) {
          ArkExitStatus.claimed => ArkExitStepState.done,
          ArkExitStatus.claimable ||
          ArkExitStatus.submitted => ArkExitStepState.current,
          _ => ArkExitStepState.upcoming,
        },
      ),
    ];
  }

  Widget _detailAction(
    BuildContext context,
    ArkAccountId account,
    ArkExit exit,
  ) {
    final l10n = arkLocalizationsOf(context);
    // Claims are automatic: there is nothing to press, only to close.
    return BullButton.big(
      label: l10n.exitDone,
      onPressed: _closeDetails,
      bgColor: context.bull.inverseSurface,
      textColor: context.bull.surface,
    );
  }
}

String arkExitStatusLabel(ArkLocalizations l10n, ArkExitStatus status) =>
    switch (status) {
      ArkExitStatus.unknown => l10n.exitStatusUnknown,
      ArkExitStatus.none => l10n.exitStatusNone,
      ArkExitStatus.pending => l10n.exitStatusPending,
      ArkExitStatus.claimable => l10n.exitStatusClaimable,
      ArkExitStatus.submitted => l10n.exitStatusSubmitted,
      ArkExitStatus.claimed => l10n.exitStatusClaimed,
      ArkExitStatus.failed => l10n.exitStatusFailed,
    };

class _EmergencyOnlyCard extends StatelessWidget {
  const _EmergencyOnlyCard();

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final colors = context.bull;
    return Container(
      padding: const EdgeInsets.all(BullSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(context.bullShapes.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: BullIcon(
                BullIcons.warningAmber,
                size: 18,
                color: colors.primary,
              ),
            ),
          ),
          const Gap(BullSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: BullText(
                    l10n.emergencyOnlyTitle,
                    role: BullTextRole.body,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(BullSpacing.xxs),
                BullText(
                  l10n.emergencyOnlyBody,
                  role: BullTextRole.label,
                  color: colors.textMuted,
                ),
                const Gap(BullSpacing.xxs),
                BullText(
                  l10n.emergencySendInstead,
                  role: BullTextRole.label,
                  color: colors.textMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Whether the Ark server answers, and the normal way out while it does:
/// sending the Ark balance to an on-chain address.
class _ServerStatusBanner extends StatelessWidget {
  final bool online;
  final VoidCallback? onSendOnChain;

  const _ServerStatusBanner({
    required this.online,
    required this.onSendOnChain,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final colors = context.bull;
    final send = onSendOnChain;
    final tone = online ? colors.success : colors.error;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BullSpacing.md,
        vertical: BullSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(context.bullShapes.card),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
          const Gap(BullSpacing.xs),
          Expanded(
            child: BullText(
              online ? l10n.exitServerOnline : l10n.exitServerOffline,
              role: BullTextRole.body,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (send != null) ...[
            const Gap(BullSpacing.sm),
            BullButton.small(
              label: l10n.exitSendOnChain,
              onPressed: send,
              bgColor: colors.inverseSurface,
              textColor: colors.surface,
              textStyle: context.bullType.label.copyWith(
                fontWeight: FontWeight.w600,
              ),
              compact: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// A quiet grey line, such as the note that the data shown was last observed.
class _Note extends StatelessWidget {
  final String text;

  const _Note(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      BullSpacing.md,
      BullSpacing.sm,
      BullSpacing.md,
      0,
    ),
    child: BullText(
      text,
      role: BullTextRole.label,
      color: context.bull.textMuted,
    ),
  );
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  const _StateCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BullSpacing.lg),
      decoration: BoxDecoration(
        color: context.bull.surface,
        borderRadius: BorderRadius.circular(context.bullShapes.card),
      ),
      child: Column(
        children: [
          BullIcon(icon, color: iconColor),
          const Gap(BullSpacing.sm),
          BullText(
            title,
            role: BullTextRole.body,
            fontWeight: FontWeight.w600,
            textAlign: TextAlign.center,
          ),
          const Gap(BullSpacing.xxs),
          BullText(
            body,
            role: BullTextRole.label,
            color: context.bull.textMuted,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ExitRow extends StatelessWidget {
  final ArkExit exit;

  /// VTXOs exited together in this one exit.
  final int count;
  final VoidCallback onTap;

  const _ExitRow({required this.exit, required this.onTap, this.count = 1});

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final amount = formatArkObservedSats(context, exit.amount);
    final status = arkExitStatusLabel(l10n, exit.status);
    return Semantics(
      button: true,
      label: l10n.exitRowSemantics(amount, status),
      excludeSemantics: true,
      onTap: onTap,
      // A row of the one exits card, as the VTXO list draws its rows: no
      // box of its own.
      child: GestureDetector(
        key: ValueKey('exit-row-${exit.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              BullSpacing.md,
              BullSpacing.sm,
              BullSpacing.sm,
              BullSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BullText(amount, role: BullTextRole.subtitle),
                      // How many VTXOs this exit took, one or several.
                      BullText(
                        l10n.exitVtxoCount(count),
                        role: BullTextRole.caption,
                        color: context.bull.textMuted,
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: exit.status),
                BullIcon(BullIcons.chevronRight, color: context.bull.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ArkExitStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final color = switch (status) {
      ArkExitStatus.failed => context.bull.error,
      ArkExitStatus.pending ||
      ArkExitStatus.claimable ||
      ArkExitStatus.submitted => context.bull.warning,
      _ => context.bull.textMuted,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: BullSpacing.xs,
          height: BullSpacing.xs,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        BullBadge(
          label: arkExitStatusLabel(l10n, status),
          background: context.bull.transparent,
          foreground: color,
        ),
      ],
    );
  }
}

/// How far along the observed steps are: done steps fill the bar, the
/// current one counts half. Green once every step is done.
class _StepProgress extends StatelessWidget {
  final List<ArkExitStep> steps;

  const _StepProgress({required this.steps});

  @override
  Widget build(BuildContext context) {
    final done = steps.where((s) => s.state == ArkExitStepState.done).length;
    final current = steps.any((s) => s.state == ArkExitStepState.current);
    final value = (done + (current ? 0.5 : 0)) / steps.length;
    final complete = done == steps.length;
    final radius = BorderRadius.circular(context.bullShapes.dot);
    return ExcludeSemantics(
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: context.bull.surfaceContainer,
          borderRadius: radius,
        ),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0, 1).toDouble(),
          heightFactor: 1,
          child: Container(
            decoration: BoxDecoration(
              color: complete ? context.bull.success : context.bull.primary,
              borderRadius: radius,
            ),
          ),
        ),
      ),
    );
  }
}
