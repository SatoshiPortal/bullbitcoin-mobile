import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:intl/intl.dart';
import 'package:primitives/primitives.dart' show Sats;

import '../../generated/l10n/ark_localizations.dart';
import '../presentation/ark_l10n.dart';
import 'ark_amount.dart';

enum _VtxoFilter { all, active, expiring, expired, locked }

/// How a VTXO reads on this screen. [other] covers states the snapshot cannot
/// place on the expiry timeline (spent, exited, unknown, or no current tip).
enum _VtxoKind { active, expiring, expired, locked, other }

/// Mainnet target spacing; the estimates it feeds are always shown with `~`.
const _blocksPerHour = 6;
const _blocksPerDay = 144;

class ArkVtxosScreen extends StatefulWidget {
  final ArkSnapshot snapshot;

  /// The account's renewal threshold, which marks a VTXO as expiring.
  final int renewalThresholdBlocks;

  /// Reviews a renewal of the ids; true once one started (or may have).
  final Future<bool> Function(List<String> ids) onRenew;

  /// Opens boarding from the empty state; the link is hidden when null.
  final VoidCallback? onBoard;
  const ArkVtxosScreen({
    super.key,
    required this.snapshot,
    required this.renewalThresholdBlocks,
    required this.onRenew,
    this.onBoard,
  });

  @override
  State<ArkVtxosScreen> createState() => _ArkVtxosScreenState();
}

class _ArkVtxosScreenState extends State<ArkVtxosScreen> {
  _VtxoFilter _filter = _VtxoFilter.all;
  String? _detailsId;

  /// The inventory can be trusted: fresh, complete, recovered, with a tip.
  bool _observed(ArkSnapshot snapshot) =>
      !snapshot.stale &&
      snapshot.vtxoInventoryComplete &&
      snapshot.tipHeight != null &&
      snapshot.recovery == ArkRecoveryStatus.complete;

  /// Observed, and no renewal already under way: VTXOs may be renewed.
  bool _current(ArkSnapshot snapshot) =>
      _observed(snapshot) && snapshot.renewal != ArkRenewalStatus.delegated;

  Set<String> _eligible(ArkSnapshot snapshot) {
    final tip = snapshot.tipHeight;
    if (!_current(snapshot) || tip == null) return {};
    return {
      for (final v in snapshot.vtxos)
        if (v.eligibleAt(tip)) v.id,
    };
  }

  ArkVtxo? _uniqueVtxo(String? id) {
    if (id == null) return null;
    final matches = widget.snapshot.vtxos.where((v) => v.id == id);
    return matches.length == 1 ? matches.single : null;
  }

  @override
  void didUpdateWidget(ArkVtxosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.account != widget.snapshot.account) {
      _detailsId = null;
      _filter = _VtxoFilter.all;
    }
    if (_uniqueVtxo(_detailsId) == null) _detailsId = null;
  }

  void _openDetails(ArkAccountId account, String id) {
    if (widget.snapshot.account != account || _uniqueVtxo(id) == null) return;
    setState(() => _detailsId = id);
  }

  void _closeDetails() => setState(() => _detailsId = null);

  /// A started renewal returns to all the VTXOs, where this one now reads
  /// Renewing.
  Future<void> _renew(ArkAccountId account, String id) async {
    if (widget.snapshot.account != account ||
        _detailsId != id ||
        !_eligible(widget.snapshot).contains(id)) {
      return;
    }
    final started = await widget.onRenew(List.unmodifiable([id]));
    if (started && mounted && _detailsId == id) _closeDetails();
  }

  /// Blocks until expiry, or null when no fresh tip makes it knowable.
  int? _blocksLeft(ArkVtxo vtxo) {
    final tip = widget.snapshot.tipHeight;
    if (widget.snapshot.stale || tip == null) return null;
    return vtxo.expiryHeight - tip;
  }

  /// A renewal the user started for [vtxo] is under way: it is joining a
  /// round, or a renewal operation spending it has not settled yet.
  bool _renewing(ArkVtxo vtxo) =>
      vtxo.pendingRound ||
      widget.snapshot.operations.any(
        (op) =>
            op.kind == ArkOperationKind.renewal &&
            (op.status == ArkOperationStatus.admitted ||
                op.status == ArkOperationStatus.pending) &&
            op.actualIds.contains(vtxo.id),
      );

  _VtxoKind _kind(ArkVtxo vtxo) {
    // A VTXO being renewed cannot be used until the renewal ends.
    if (_renewing(vtxo) ||
        vtxo.state == ArkVtxoState.locked ||
        (vtxo.state == ArkVtxoState.spendable && vtxo.pendingRound)) {
      return _VtxoKind.locked;
    }
    final tip = widget.snapshot.tipHeight;
    if (vtxo.state != ArkVtxoState.spendable ||
        widget.snapshot.stale ||
        tip == null) {
      return _VtxoKind.other;
    }
    if (vtxo.expiryHeight <= tip) return _VtxoKind.expired;
    if (vtxo.renewalDueAt(tip, widget.renewalThresholdBlocks)) {
      return _VtxoKind.expiring;
    }
    return _VtxoKind.active;
  }

  /// Spent and exited VTXOs are history, not holdings, and one under an
  /// emergency exit is followed there: the list never shows them.
  List<ArkVtxo> _shown(ArkSnapshot snapshot) {
    final exiting = {for (final exit in snapshot.exitDetails) exit.id};
    return snapshot.vtxos
        .where(
          (v) =>
              v.state != ArkVtxoState.spent &&
              v.state != ArkVtxoState.exited &&
              // A Board released unsigned can never be funded: not money.
              v.state != ArkVtxoState.abandonedBoard &&
              !exiting.contains(v.id),
        )
        .toList();
  }

  bool _matches(ArkVtxo vtxo, _VtxoFilter filter) => switch (filter) {
    _VtxoFilter.all => true,
    _VtxoFilter.active => _kind(vtxo) == _VtxoKind.active,
    _VtxoFilter.expiring => _kind(vtxo) == _VtxoKind.expiring,
    _VtxoFilter.expired => _kind(vtxo) == _VtxoKind.expired,
    _VtxoFilter.locked => _kind(vtxo) == _VtxoKind.locked,
  };

  String _state(ArkLocalizations l10n, ArkVtxo vtxo) => switch (vtxo.state) {
    ArkVtxoState.spendable => l10n.spendableState,
    ArkVtxoState.locked => l10n.lockedState,
    ArkVtxoState.spent => l10n.spentState,
    ArkVtxoState.exited => l10n.exitedState,
    ArkVtxoState.unknown => l10n.unknownState,
    ArkVtxoState.abandonedBoard => l10n.abandonedBoardState,
  };

  String _about(ArkLocalizations l10n, int blocks) => blocks < _blocksPerDay
      ? l10n.vtxosAboutHours(
          (blocks / _blocksPerHour).round().clamp(1, _blocksPerDay),
        )
      : l10n.vtxosAboutDays((blocks / _blocksPerDay).round());

  /// When the movement that produced [vtxo] happened. Funds recovered from
  /// the server have no local history, so their creation time is unknown.
  DateTime? _createdAt(ArkSnapshot snapshot, ArkVtxo vtxo) => snapshot.movements
      .where((m) => m.outputVtxoIds.contains(vtxo.id))
      .map((m) => m.createdAt)
      .nonNulls
      .firstOrNull;

  /// One-line status under a row's amount.
  String _rowStatus(ArkLocalizations l10n, ArkVtxo vtxo) {
    final blocks = _blocksLeft(vtxo);
    return switch (_kind(vtxo)) {
      _VtxoKind.locked => l10n.vtxosLocked,
      _VtxoKind.expired => l10n.vtxosExpired,
      _VtxoKind.expiring when blocks != null => l10n.vtxosExpiringIn(
        _about(l10n, blocks),
      ),
      _VtxoKind.active when blocks != null => l10n.vtxosExpiresIn(
        _about(l10n, blocks),
      ),
      _ => _state(l10n, vtxo),
    };
  }

  Color _statusColor(BuildContext context, _VtxoKind kind) => switch (kind) {
    _VtxoKind.expired => context.bull.error,
    _VtxoKind.expiring => context.bull.warning,
    _ => context.bull.textMuted,
  };

  String _short(String value) => value.length <= 20
      ? value
      : '${value.substring(0, 8)}…${value.substring(value.length - 6)}';

  String _filterLabel(ArkLocalizations l10n, _VtxoFilter filter) =>
      switch (filter) {
        _VtxoFilter.all => l10n.vtxoAll,
        _VtxoFilter.active => l10n.vtxosFilterActive,
        _VtxoFilter.expiring => l10n.vtxosFilterExpiring,
        _VtxoFilter.expired => l10n.vtxoExpired,
        _VtxoFilter.locked => l10n.vtxosFilterLocked,
      };

  String _noneLabel(ArkLocalizations l10n) => switch (_filter) {
    _VtxoFilter.all => l10n.vtxosNoneAll,
    _VtxoFilter.active => l10n.vtxosNoneActive,
    _VtxoFilter.expiring => l10n.vtxosNoneExpiring,
    _VtxoFilter.expired => l10n.vtxosNoneExpired,
    _VtxoFilter.locked => l10n.vtxosNoneLocked,
  };

  /// What limits the data shown, as a quiet grey line: never a bare
  /// "Unavailable", and nothing while a renewal is simply under way.
  List<Widget> _warnings(ArkLocalizations l10n, ArkSnapshot snapshot) {
    final String? message = snapshot.stale
        ? l10n.stale
        : snapshot.recovery != ArkRecoveryStatus.complete
        ? l10n.recovery
        : !_observed(snapshot)
        ? l10n.vtxosIncomplete
        : null;
    if (message == null) return const [];
    return [
      BullText(
        message,
        role: BullTextRole.label,
        color: context.bull.textMuted,
      ),
      const Gap(BullSpacing.sm),
    ];
  }

  Widget _filters(ArkLocalizations l10n, ArkSnapshot snapshot) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final filter in _VtxoFilter.values)
              Padding(
                padding: const EdgeInsets.only(right: BullSpacing.xs),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Center(
                    heightFactor: 1,
                    child: _FilterChip(
                      label: l10n.vtxosFilterCount(
                        _filterLabel(l10n, filter),
                        _shown(snapshot)
                            .where((v) => _matches(v, filter))
                            .length,
                      ),
                      selected: _filter == filter,
                      onTap: () => setState(() => _filter = filter),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _summary(ArkLocalizations l10n, ArkSnapshot snapshot) {
    final live = _shown(snapshot).where(
      (v) => const {
        _VtxoKind.active,
        _VtxoKind.expiring,
        _VtxoKind.locked,
      }.contains(_kind(v)),
    );
    // An unknown-state VTXO makes the total unknowable, not smaller.
    final knowable =
        _observed(snapshot) &&
        !snapshot.vtxos.any((v) => v.state == ArkVtxoState.unknown);
    final total = live.fold<BigInt>(BigInt.zero, (s, v) => s + v.amount.value);
    final next = live
        .where((v) => _kind(v) != _VtxoKind.locked)
        .map(_blocksLeft)
        .whereType<int>()
        .fold<int?>(null, (min, b) => min == null || b < min ? b : min);
    return Container(
      padding: const EdgeInsets.all(BullSpacing.lg),
      decoration: BoxDecoration(
        color: context.bull.surface,
        borderRadius: BorderRadius.circular(context.bullShapes.card),
      ),
      child: Semantics(
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BullText(
              l10n.vtxosTotalInArk,
              role: BullTextRole.label,
              color: context.bull.textMuted,
            ),
            const Gap(BullSpacing.xxs),
            BullText(
              formatArkObservedSats(context, knowable ? Sats(total) : null),
              role: BullTextRole.headline,
              fontWeight: FontWeight.w700,
            ),
            if (knowable) ...[
              const Gap(BullSpacing.xxs),
              BullText(
                next == null
                    ? l10n.vtxosCount(live.length)
                    : l10n.vtxosCountNextExpiry(
                        live.length,
                        _about(l10n, next),
                      ),
                role: BullTextRole.label,
                color: context.bull.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(ArkLocalizations l10n, ArkAccountId account, ArkVtxo vtxo) {
    final kind = _kind(vtxo);
    final status = _rowStatus(l10n, vtxo);
    final color = _statusColor(context, kind);
    final amount = formatArkObservedSats(context, vtxo.amount);
    final dot = switch (kind) {
      _VtxoKind.expired || _VtxoKind.expiring || _VtxoKind.locked => color,
      _ => null,
    };
    return Semantics(
      button: true,
      label: l10n.vtxosRowSemantics(amount, status),
      onTap: () => _openDetails(account, vtxo.id),
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('vtxo-details-${vtxo.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _openDetails(account, vtxo.id),
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
                      BullText(
                        amount,
                        role: BullTextRole.body,
                        fontWeight: FontWeight.w600,
                      ),
                      const Gap(BullSpacing.xxs),
                      Row(
                        children: [
                          if (dot != null) ...[
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: dot,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const Gap(BullSpacing.xs),
                          ],
                          Flexible(
                            child: BullText(
                              status,
                              role: BullTextRole.caption,
                              color: color,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                BullIcon(BullIcons.chevronRight, color: context.bull.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _list(ArkLocalizations l10n, ArkSnapshot snapshot) {
    final values = _shown(snapshot).where((v) => _matches(v, _filter)).toList()
      ..sort((a, b) => a.expiryHeight.compareTo(b.expiryHeight));
    if (values.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BullSpacing.md,
          vertical: BullSpacing.xl,
        ),
        child: BullText(
          _noneLabel(l10n),
          role: BullTextRole.body,
          textAlign: TextAlign.center,
          color: context.bull.textMuted,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: context.bull.surface,
        borderRadius: BorderRadius.circular(context.bullShapes.card),
      ),
      child: Column(
        children: [
          for (final (index, vtxo) in values.indexed) ...[
            if (index > 0)
              Container(height: 1, color: context.bull.outlineVariant),
            _row(l10n, snapshot.account, vtxo),
          ],
        ],
      ),
    );
  }

  Widget _empty(ArkLocalizations l10n) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: BullSpacing.xl,
      vertical: BullSpacing.xxl,
    ),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: context.bull.surfaceContainer,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: BullIcon(
              BullIcons.accountBalanceWallet,
              size: 28,
              color: context.bull.textMuted,
            ),
          ),
        ),
        const Gap(BullSpacing.sm),
        Semantics(
          header: true,
          child: BullText(
            _filter == _VtxoFilter.all ? l10n.vtxosEmptyAll : _noneLabel(l10n),
            role: BullTextRole.subtitle,
            fontWeight: FontWeight.w600,
            textAlign: TextAlign.center,
          ),
        ),
        const Gap(BullSpacing.xs),
        BullText(
          l10n.vtxosEmptyBody,
          role: BullTextRole.body,
          textAlign: TextAlign.center,
          color: context.bull.textMuted,
        ),
        if (widget.onBoard case final onBoard?) ...[
          const Gap(BullSpacing.lg),
          BullButton.secondary(
            label: l10n.vtxosBoardToArk,
            onPressed: onBoard,
            size: BullButtonSize.small,
            compact: true,
          ),
        ],
      ],
    ),
  );

  Widget _listView(ArkLocalizations l10n, ArkSnapshot snapshot) {
    final current = _observed(snapshot);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BullTopBar(
          title: l10n.vtxos,
          onBack: () => Navigator.maybePop(context),
        ),
        if (_shown(snapshot).isEmpty && current) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BullSpacing.md,
              BullSpacing.xxs,
              BullSpacing.md,
              BullSpacing.zero,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._warnings(l10n, snapshot),
                _filters(l10n, snapshot),
              ],
            ),
          ),
          // The empty state sits in the middle of the space left under the
          // filters, and still scrolls when that space is too small.
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(child: _empty(l10n)),
                ),
              ),
            ),
          ),
        ] else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                BullSpacing.md,
                BullSpacing.xxs,
                BullSpacing.md,
                BullSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._warnings(l10n, snapshot),
                  if (_shown(snapshot).isNotEmpty) ...[
                    _summary(l10n, snapshot),
                    const Gap(BullSpacing.xs),
                    _filters(l10n, snapshot),
                    const Gap(BullSpacing.xs),
                    _list(l10n, snapshot),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _details(ArkLocalizations l10n, ArkVtxo vtxo) {
    final snapshot = widget.snapshot;
    final kind = _kind(vtxo);
    final blocks = _blocksLeft(vtxo);
    final eligible = _eligible(snapshot).contains(vtxo.id);
    final canRenew =
        (kind == _VtxoKind.active || kind == _VtxoKind.expiring) &&
        !_renewing(vtxo);
    final account = snapshot.account;
    final (icon, iconColor, iconBackground) = switch (kind) {
      _VtxoKind.expired => (
        BullIcons.close,
        context.bull.error,
        context.bull.errorContainer,
      ),
      _VtxoKind.expiring => (
        BullIcons.schedule,
        context.bull.warning,
        context.bull.warningContainer,
      ),
      _VtxoKind.locked => (
        BullIcons.sync,
        context.bull.textMuted,
        context.bull.surfaceContainer,
      ),
      _ => (
        BullIcons.schedule,
        context.bull.textMuted,
        context.bull.surfaceContainer,
      ),
    };
    final renewing = _renewing(vtxo);
    final headline = switch (kind) {
      _VtxoKind.locked => l10n.vtxosLocked,
      _VtxoKind.expiring => l10n.vtxosExpiring,
      _ => _rowStatus(l10n, vtxo),
    };
    final note = switch (kind) {
      // "Renewing" above says it all; the round needs nothing from the user.
      _ when renewing => null,
      // Action needed: the app's warning card.
      _VtxoKind.expiring => BullInfoCard(
        description: l10n.vtxosRenewNoteDue(
          widget.renewalThresholdBlocks.toString(),
        ),
        tagColor: context.bull.tertiary,
        bgColor: context.bull.warningContainer,
      ),
      _VtxoKind.active => BullText(
        l10n.vtxosRenewNote(
          (widget.renewalThresholdBlocks / _blocksPerDay).ceil().clamp(1, 365),
        ),
        role: BullTextRole.label,
        color: context.bull.textMuted,
      ),
      _VtxoKind.expired => BullInfoCard(
        description: l10n.vtxosExpiredNote,
        tagColor: context.bull.tertiary,
        bgColor: context.bull.warningContainer,
      ),
      _VtxoKind.locked => BullText(
        l10n.vtxosLockedNote,
        role: BullTextRole.label,
        color: context.bull.textMuted,
      ),
      _VtxoKind.other => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BullTopBar(title: l10n.vtxoDetails, onBack: _closeDetails),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              BullSpacing.md,
              BullSpacing.xxs,
              BullSpacing.md,
              BullSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._warnings(l10n, snapshot),
                const Gap(BullSpacing.md),
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: BullIcon(icon, size: 28, color: iconColor),
                    ),
                  ),
                ),
                const Gap(BullSpacing.sm),
                BullText(
                  formatArkObservedSats(context, vtxo.amount),
                  role: BullTextRole.headline,
                  textAlign: TextAlign.center,
                  fontWeight: FontWeight.w700,
                ),
                const Gap(BullSpacing.xxs),
                BullText(
                  headline,
                  role: BullTextRole.body,
                  textAlign: TextAlign.center,
                  color: kind == _VtxoKind.active
                      ? context.bull.text
                      : _statusColor(context, kind),
                ),
                const Gap(BullSpacing.lg),
                BullDetailsTable(
                  items: [
                    BullDetailsTableItem(
                      label: l10n.state,
                      // A VTXO being renewed cannot be spent until its round.
                      displayValue: kind == _VtxoKind.expired
                          ? l10n.vtxosExpired
                          : renewing
                          ? l10n.lockedState
                          : _state(l10n, vtxo),
                    ),
                    BullDetailsTableItem(
                      label: l10n.vtxosExpires,
                      displayValue: l10n.vtxosBlockHeight(
                        vtxo.expiryHeight.toString(),
                      ),
                    ),
                    BullDetailsTableItem(
                      label: l10n.vtxosBlocksLeft,
                      displayValue: switch (blocks) {
                        null => l10n.unknown,
                        <= 0 => '0',
                        final left => l10n.vtxosBlocksLeftValue(
                          left.toString(),
                          _about(l10n, left),
                        ),
                      },
                    ),
                    if (_createdAt(snapshot, vtxo) case final created?)
                      BullDetailsTableItem(
                        label: l10n.vtxoCreated,
                        displayValue: DateFormat.yMMMMd(
                          Localizations.localeOf(context).toString(),
                        ).add_jm().format(created.toLocal()),
                      ),
                    BullDetailsTableItem(
                      label: l10n.vtxosId,
                      displayValue: _short(vtxo.id),
                      copyValue: vtxo.id,
                      copiedMessage: l10n.vtxosIdCopied,
                    ),
                    BullDetailsTableItem(
                      label: l10n.vtxosAnchorPoint,
                      displayValue: switch (vtxo.anchor) {
                        final anchor? => _short(anchor),
                        null => l10n.unknown,
                      },
                      copyValue: vtxo.anchor,
                      copiedMessage: l10n.vtxosAnchorCopied,
                    ),
                  ],
                ),
                if (note != null) ...[const Gap(BullSpacing.md), note],
              ],
            ),
          ),
        ),
        if (canRenew)
          Padding(
            padding: const EdgeInsets.all(BullSpacing.md),
            child: BullButton.primary(
              label: l10n.vtxosRenew,
              onPressed: eligible
                  ? () => unawaited(_renew(account, vtxo.id))
                  : null,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final details = _uniqueVtxo(_detailsId);
    return PopScope<Object?>(
      canPop: details == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeDetails();
      },
      child: BullScaffold(
        backgroundColor: context.bull.background,
        body: SafeArea(
          child: details != null
              ? _details(l10n, details)
              : _listView(l10n, widget.snapshot),
        ),
      ),
    );
  }
}

/// A filter as the Coins sort and filter sheet draws its options: square
/// corners, and a light red fill with a red border once selected.
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // The whole row height is the tap target, not only the drawn chip.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(heightFactor: 1, child: _chip(context, colors)),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, BullTheme colors) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: selected ? colors.primary.withValues(alpha: 0.08) : colors.surface,
      borderRadius: BorderRadius.circular(context.bullShapes.button),
      border: Border.all(
        color: selected ? colors.primary : colors.outlineVariant,
        width: selected ? 1.5 : 1,
      ),
    ),
    child: Text(
      label,
      style: context.bullType.caption.copyWith(
        color: selected ? colors.primary : colors.text,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    ),
  );
}
