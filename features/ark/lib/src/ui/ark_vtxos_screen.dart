import 'package:ark/ark.dart';
import 'package:intl/intl.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:primitives/primitives.dart' show Sats;

import '../presentation/ark_l10n.dart';
import 'ark_amount.dart';

enum _VtxoFilter { all, active, expiring, expired, locked }

class ArkVtxosScreen extends StatefulWidget {
  final ArkSnapshot snapshot;
  final ValueChanged<List<String>> onRenew;
  final VoidCallback? onBoard;
  final int? renewalThresholdBlocks;

  const ArkVtxosScreen({
    super.key,
    required this.snapshot,
    required this.onRenew,
    this.onBoard,
    this.renewalThresholdBlocks,
  });

  @override
  State<ArkVtxosScreen> createState() => _ArkVtxosScreenState();
}

class _ArkVtxosScreenState extends State<ArkVtxosScreen> {
  _VtxoFilter _filter = _VtxoFilter.all;
  String? _detailsId;
  Object _detailsPublication = Object();

  bool _observed(ArkSnapshot snapshot) =>
      !snapshot.stale &&
      snapshot.vtxoInventoryComplete &&
      snapshot.tipHeight != null;

  bool _current(ArkSnapshot snapshot) =>
      _observed(snapshot) &&
      snapshot.recovery == ArkRecoveryStatus.complete &&
      snapshot.renewal != ArkRenewalStatus.delegated;

  bool _retired(ArkVtxo vtxo) => switch (vtxo.state) {
    ArkVtxoState.spent ||
    ArkVtxoState.exited ||
    ArkVtxoState.abandonedBoard => true,
    _ => false,
  };

  ArkVtxo? _uniqueVtxo(String? id) {
    if (id == null) return null;
    final matches = widget.snapshot.vtxos.where((v) => v.id == id);
    if (matches.length != 1 || _retired(matches.single)) return null;
    return matches.single;
  }

  @override
  void didUpdateWidget(ArkVtxosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.account != widget.snapshot.account) {
      _detailsId = null;
      _filter = _VtxoFilter.all;
    }
    if (_uniqueVtxo(_detailsId) == null) _detailsId = null;
    // Any new publication retires actions saved from the previous frame.
    _detailsPublication = Object();
  }

  int? _blocks(ArkVtxo vtxo) {
    final tip = widget.snapshot.tipHeight;
    return widget.snapshot.stale || tip == null
        ? null
        : vtxo.expiryHeight - tip;
  }

  _VtxoFilter? _kind(ArkVtxo vtxo) {
    if (vtxo.state == ArkVtxoState.locked) return _VtxoFilter.locked;
    final blocks = _blocks(vtxo);
    if (vtxo.state != ArkVtxoState.spendable ||
        vtxo.pendingRound ||
        blocks == null) {
      return null;
    }
    if (blocks <= 0) return _VtxoFilter.expired;
    return blocks <= 144 ? _VtxoFilter.expiring : _VtxoFilter.active;
  }

  bool _matches(ArkVtxo vtxo, _VtxoFilter filter) =>
      !_retired(vtxo) && (filter == _VtxoFilter.all || _kind(vtxo) == filter);

  bool _eligible(ArkVtxo vtxo) {
    final tip = widget.snapshot.tipHeight;
    return _current(widget.snapshot) &&
        tip != null &&
        _uniqueVtxo(vtxo.id) != null &&
        vtxo.eligibleAt(tip);
  }

  void _openDetails(ArkAccountId account, String id) {
    if (!mounted ||
        widget.snapshot.account != account ||
        _uniqueVtxo(id) == null) {
      return;
    }
    setState(() {
      _detailsId = id;
      _detailsPublication = Object();
    });
  }

  void _closeDetails() => setState(() {
    _detailsId = null;
    _detailsPublication = Object();
  });

  void _review(
    ArkSnapshot publication,
    Object detailsPublication,
    String id,
    ValueChanged<List<String>> capability,
  ) {
    if (!mounted ||
        !identical(widget.snapshot, publication) ||
        !identical(_detailsPublication, detailsPublication) ||
        !identical(widget.onRenew, capability) ||
        _detailsId != id) {
      return;
    }
    final vtxo = _uniqueVtxo(id);
    if (vtxo != null && _eligible(vtxo)) capability(List.unmodifiable([id]));
  }

  void _board(ArkAccountId account, VoidCallback capability) {
    if (!mounted ||
        widget.snapshot.account != account ||
        !identical(widget.onBoard, capability) ||
        !_current(widget.snapshot) ||
        widget.snapshot.vtxos.isNotEmpty) {
      return;
    }
    capability();
  }

  String _label(BuildContext context, _VtxoFilter filter) {
    final l10n = context.loc;
    return switch (filter) {
      _VtxoFilter.all => l10n.vtxoAll,
      _VtxoFilter.active => l10n.inventoryActive,
      _VtxoFilter.expiring => l10n.inventoryExpiring,
      _VtxoFilter.expired => l10n.vtxoExpired,
      _VtxoFilter.locked => l10n.lockedState,
    };
  }

  String _integer(BuildContext context, int? value) => value == null
      ? context.loc.unknown
      : NumberFormat.decimalPattern(Localizations.localeOf(context).toString())
            .format(value);

  Widget _scroll({
    required Widget child,
    required EdgeInsets padding,
    required bool fill,
  }) => LayoutBuilder(
    builder: (context, viewport) => SingleChildScrollView(
      padding: padding,
      child: fill
          ? ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (viewport.maxHeight - padding.vertical)
                    .clamp(0.0, viewport.maxHeight)
                    .toDouble(),
              ),
              child: child,
            )
          : child,
    ),
  );

  String _status(BuildContext context, ArkVtxo vtxo) {
    final l10n = context.loc;
    final blocks = _blocks(vtxo);
    return switch (_kind(vtxo)) {
      _VtxoFilter.locked => l10n.lockedState,
      _VtxoFilter.expired => l10n.vtxoExpired,
      _VtxoFilter.expiring => l10n.inventoryExpiringIn(blocks.toString()),
      _VtxoFilter.active => l10n.inventoryExpiresIn(blocks.toString()),
      _ => l10n.unknown,
    };
  }

  Color _statusColor(BuildContext context, ArkVtxo vtxo) =>
      switch (_kind(vtxo)) {
        _VtxoFilter.expired => context.bull.error,
        _VtxoFilter.expiring => context.bull.warning,
        _ => context.bull.textMuted,
      };

  Widget _filters(
    BuildContext context,
    List<ArkVtxo> inventory,
  ) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final filter in _VtxoFilter.values)
          Padding(
            padding: const EdgeInsets.only(right: BullSpacing.sm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: BullFilterChip.selectable(
                label:
                    '${_label(context, filter)} ${_integer(context, inventory.where((v) => _matches(v, filter)).length)}',
                selected: _filter == filter,
                selectionColor: context.bull.secondary,
                onSelected: (_) => setState(() => _filter = filter),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _details(BuildContext context, ArkVtxo vtxo) {
    final l10n = context.loc;
    final blocks = _blocks(vtxo);
    final kind = _kind(vtxo);
    final tip = widget.snapshot.tipHeight;
    final threshold = widget.renewalThresholdBlocks;
    final renewalDue =
        _eligible(vtxo) &&
        tip != null &&
        threshold != null &&
        vtxo.renewalDueAt(tip, threshold);
    final note = switch (kind) {
      _VtxoFilter.expired => l10n.inventoryExpiredNote,
      _VtxoFilter.locked => l10n.inventoryLockedNote,
      _ when renewalDue => l10n.inventoryRenewNote(
        _integer(context, threshold),
      ),
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap(BullSpacing.lg),
        Center(
          child: Container(
            padding: const EdgeInsets.all(BullSpacing.lg),
            decoration: BoxDecoration(
              color: context.bull.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: BullIcon(
              kind == _VtxoFilter.locked
                  ? BullIcons.lockOpen
                  : BullIcons.schedule,
              size: 28,
              color: _statusColor(context, vtxo),
            ),
          ),
        ),
        const Gap(BullSpacing.md),
        BullText(
          formatArkObservedSats(context, vtxo.amount),
          role: BullTextRole.headline,
          textAlign: TextAlign.center,
          fontWeight: FontWeight.w700,
        ),
        const Gap(BullSpacing.sm),
        BullText(
          _status(context, vtxo),
          role: BullTextRole.body,
          textAlign: TextAlign.center,
          color: _statusColor(context, vtxo),
        ),
        const Gap(BullSpacing.lg),
        BullDetailsTable(
          flat: true,
          items: [
            BullDetailsTableItem(
              label: l10n.state,
              displayValue:
                  kind == _VtxoFilter.active || kind == _VtxoFilter.expiring
                  ? l10n.spendableState
                  : _status(context, vtxo),
            ),
            BullDetailsTableItem(
              label: l10n.inventoryExpires,
              displayValue: l10n.inventoryBlockHeight(
                _integer(context, vtxo.expiryHeight),
              ),
            ),
            BullDetailsTableItem(
              label: l10n.inventoryBlocksLeft,
              displayValue: blocks == null
                  ? l10n.unknown
                  : _integer(context, blocks < 0 ? 0 : blocks),
            ),
            BullDetailsTableItem(
              label: l10n.vtxoCreated,
              displayValue: l10n.unknown,
            ),
            BullDetailsTableItem(
              compact: true,
              label: l10n.inventoryVtxoId,
              displayValue: _short(vtxo.id),
              copyValue: vtxo.id,
              copiedMessage: l10n.copied,
            ),
            BullDetailsTableItem(
              compact: true,
              label: l10n.inventoryAnchor,
              displayValue: switch (vtxo.anchor) {
                final anchor? => _short(anchor),
                null => l10n.unknown,
              },
              copyValue: vtxo.anchor,
              copiedMessage: l10n.copied,
            ),
          ],
        ),
        if (note != null) ...[
          const Gap(BullSpacing.md),
          BullInfoBar(message: note),
        ],
      ],
    );
  }

  String _short(String value) => value.length <= 22
      ? value
      : '${value.substring(0, 10)}…${value.substring(value.length - 8)}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.loc;
    final snapshot = widget.snapshot;
    final board = widget.onBoard;
    final capability = widget.onRenew;
    final publication = _detailsPublication;
    final details = _uniqueVtxo(_detailsId);
    final inventory = snapshot.vtxos.where((v) => !_retired(v)).toList()
      ..sort((a, b) {
        final order = a.expiryHeight.compareTo(b.expiryHeight);
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
    final values = inventory.where((v) => _matches(v, _filter));
    final live = inventory
        .where(
          (v) => switch (_kind(v)) {
            _VtxoFilter.active ||
            _VtxoFilter.expiring ||
            _VtxoFilter.locked => true,
            _ => false,
          },
        )
        .toList();
    final total = live.fold<BigInt>(
      BigInt.zero,
      (sum, v) => sum + v.amount.value,
    );
    final complete =
        _observed(snapshot) && inventory.every((v) => _kind(v) != null);
    final upcoming = live
        .where((v) => _kind(v) != _VtxoFilter.locked)
        .firstOrNull;
    final nextBlocks = upcoming == null ? null : _blocks(upcoming);
    final rawEmpty = snapshot.vtxos.isEmpty && _current(snapshot);
    return BullScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BullSpacing.md),
              child: BullTopBar(
                title: details == null ? l10n.vtxos : l10n.vtxoDetails,
                onBack: details == null
                    ? () => Navigator.pop(context)
                    : _closeDetails,
              ),
            ),
            Expanded(
              child: _scroll(
                fill: rawEmpty && details == null,
                padding: const EdgeInsets.all(BullSpacing.md),
                child: details != null
                    ? _details(context, details)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: rawEmpty
                            ? MainAxisAlignment.spaceBetween
                            : MainAxisAlignment.start,
                        children: [
                          if (snapshot.stale) BullInfoBar(message: l10n.stale),
                          if (!_observed(snapshot))
                            BullInfoBar(message: l10n.unknown),
                          if (inventory.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(BullSpacing.lg),
                              decoration: BoxDecoration(
                                color: context.bull.surface,
                                borderRadius: BorderRadius.circular(
                                  context.bullShapes.card,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BullText(
                                    l10n.inventoryTotal,
                                    role: BullTextRole.label,
                                    color: context.bull.textMuted,
                                  ),
                                  const Gap(BullSpacing.xs),
                                  BullText(
                                    formatArkObservedSats(
                                      context,
                                      complete ? Sats(total) : null,
                                    ),
                                    role: BullTextRole.headline,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  BullText(
                                    complete
                                        ? '${_integer(context, live.length)} ${l10n.vtxoCount}'
                                        : l10n.unknown,
                                    role: BullTextRole.label,
                                    color: context.bull.textMuted,
                                  ),
                                  if (complete && nextBlocks != null)
                                    BullText(
                                      l10n.inventoryNextExpiry(
                                        nextBlocks.toString(),
                                      ),
                                      role: BullTextRole.label,
                                      color: context.bull.textMuted,
                                    ),
                                ],
                              ),
                            ),
                            const Gap(BullSpacing.md),
                          ],
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: BullSpacing.md,
                            ),
                            child: _filters(context, inventory),
                          ),
                          if (rawEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: BullSpacing.zero,
                              ),
                              child: Column(
                                children: [
                                  BullIcon(
                                    BullIcons.accountTree,
                                    size: 48,
                                    color: context.bull.textMuted,
                                  ),
                                  const Gap(BullSpacing.lg),
                                  BullText(
                                    _filter == _VtxoFilter.all
                                        ? l10n.inventoryEmptyTitle
                                        : l10n.vtxoNoMatches,
                                    role: BullTextRole.subtitle,
                                    textAlign: TextAlign.center,
                                  ),
                                  const Gap(BullSpacing.sm),
                                  BullText(
                                    l10n.inventoryEmptyBody,
                                    role: BullTextRole.body,
                                    textAlign: TextAlign.center,
                                    color: context.bull.textMuted,
                                  ),
                                  if (board != null) ...[
                                    const Gap(BullSpacing.lg),
                                    BullButton.small(
                                      compact: true,
                                      height: 48,
                                      label: l10n.boardToArk,
                                      onPressed: () =>
                                          _board(snapshot.account, board),
                                      bgColor: context.bull.secondary,
                                      textColor: context.bull.onSecondary,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox.shrink(),
                          ] else if (values.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(BullSpacing.lg),
                              child: BullText(
                                _current(snapshot)
                                    ? l10n.vtxoNoMatches
                                    : l10n.unknown,
                                role: BullTextRole.body,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          for (final vtxo in values)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: BullSpacing.zero,
                              ),
                              child: Semantics(
                                button: true,
                                label:
                                    '${formatArkObservedSats(context, vtxo.amount)}, ${_status(context, vtxo)}, ${l10n.vtxoDetails}',
                                child: BullBorderedTile(
                                  key: ValueKey('vtxo-details-${vtxo.id}'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: BullSpacing.md,
                                    vertical: BullSpacing.xs,
                                  ),
                                  onTap: () =>
                                      _openDetails(snapshot.account, vtxo.id),
                                  backgroundColor: context.bull.surface,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            BullText(
                                              formatArkObservedSats(
                                                context,
                                                vtxo.amount,
                                              ),
                                              role: BullTextRole.body,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            BullText(
                                              _status(context, vtxo),
                                              role: BullTextRole.caption,
                                              color: _statusColor(
                                                context,
                                                vtxo,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 48,
                                        height: 46,
                                        child: Center(
                                          child: BullIcon(
                                            BullIcons.chevronRight,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            if (details != null && _eligible(details))
              Padding(
                padding: const EdgeInsets.all(BullSpacing.md),
                child: BullButton.big(
                  label: l10n.inventoryRenew,
                  onPressed: () =>
                      _review(snapshot, publication, details.id, capability),
                  bgColor: context.bull.secondary,
                  textColor: context.bull.onSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
