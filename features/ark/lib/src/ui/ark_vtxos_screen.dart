import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:primitives/primitives.dart' show Sats;

import '../presentation/ark_l10n.dart';
import 'ark_amount.dart';

enum _VtxoFilter { all, spendable, locked, expired }

class ArkVtxosScreen extends StatefulWidget {
  final ArkSnapshot snapshot;
  final ValueChanged<List<String>> onRenew;
  const ArkVtxosScreen({
    super.key,
    required this.snapshot,
    required this.onRenew,
  });
  @override
  State<ArkVtxosScreen> createState() => _ArkVtxosScreenState();
}

class _ArkVtxosScreenState extends State<ArkVtxosScreen> {
  final Set<String> _selected = {};
  _VtxoFilter _filter = _VtxoFilter.all;
  String? _detailsId;

  bool _current(ArkSnapshot snapshot) =>
      !snapshot.stale &&
      snapshot.vtxoInventoryComplete &&
      snapshot.tipHeight != null &&
      snapshot.recovery == ArkRecoveryStatus.complete &&
      snapshot.renewal != ArkRenewalStatus.delegated;

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
      _selected.clear();
      _detailsId = null;
      _filter = _VtxoFilter.all;
    }
    if (_uniqueVtxo(_detailsId) == null) _detailsId = null;
    _selected.retainAll(_eligible(widget.snapshot));
  }

  void _toggle(ArkAccountId account, String id) {
    if (widget.snapshot.account != account ||
        !_eligible(widget.snapshot).contains(id)) {
      return;
    }
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  void _openDetails(ArkAccountId account, String id) {
    if (widget.snapshot.account != account || _uniqueVtxo(id) == null) return;
    setState(() => _detailsId = id);
  }

  void _review(ArkAccountId account) {
    if (widget.snapshot.account != account) return;
    final ids = _selected.intersection(_eligible(widget.snapshot));
    if (ids.isNotEmpty) widget.onRenew(List.unmodifiable(ids));
  }

  bool _expired(ArkVtxo vtxo) {
    final tip = widget.snapshot.tipHeight;
    return !widget.snapshot.stale &&
        tip != null &&
        vtxo.state == ArkVtxoState.spendable &&
        vtxo.expiryHeight <= tip;
  }

  bool _matches(ArkVtxo vtxo, _VtxoFilter filter) => switch (filter) {
    _VtxoFilter.all => true,
    _VtxoFilter.spendable =>
      vtxo.state == ArkVtxoState.spendable && !_expired(vtxo),
    _VtxoFilter.locked => vtxo.state == ArkVtxoState.locked,
    _VtxoFilter.expired => _expired(vtxo),
  };

  String _state(BuildContext context, ArkVtxo vtxo) {
    final l10n = arkLocalizationsOf(context);
    return switch (vtxo.state) {
      ArkVtxoState.spendable => l10n.spendableState,
      ArkVtxoState.locked => l10n.lockedState,
      ArkVtxoState.spent => l10n.spentState,
      ArkVtxoState.exited => l10n.exitedState,
      ArkVtxoState.unknown => l10n.unknownState,
      ArkVtxoState.abandonedBoard => l10n.abandonedBoardState,
    };
  }

  Widget _details(BuildContext context, ArkVtxo vtxo) {
    final l10n = arkLocalizationsOf(context);
    final snapshot = widget.snapshot;
    final tip = snapshot.tipHeight;
    final blocks = !snapshot.stale && tip != null
        ? (vtxo.expiryHeight - tip).clamp(0, vtxo.expiryHeight).toString()
        : l10n.unknown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BullTopBar(
          title: l10n.vtxoDetails,
          onBack: () => setState(() => _detailsId = null),
        ),
        if (snapshot.stale) BullInfoBar(message: l10n.stale),
        if (!_current(snapshot)) BullInfoBar(message: l10n.unknown),
        const Gap(BullSpacing.lg),
        Center(
          child: Container(
            padding: const EdgeInsets.all(BullSpacing.md),
            decoration: BoxDecoration(
              color: context.bull.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: BullIcon(
              vtxo.state == ArkVtxoState.locked
                  ? BullIcons.lockOpen
                  : BullIcons.schedule,
              size: 32,
              color: context.bull.textMuted,
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
        const Gap(BullSpacing.xs),
        BullText(
          _expired(vtxo) ? l10n.vtxoExpired : _state(context, vtxo),
          role: BullTextRole.body,
          textAlign: TextAlign.center,
          color: context.bull.textMuted,
        ),
        const Gap(BullSpacing.lg),
        BullDetailsTable(
          items: [
            BullDetailsTableItem(
              label: l10n.state,
              displayValue: _state(context, vtxo),
            ),
            BullDetailsTableItem(
              label: l10n.expiryHeight,
              displayValue: vtxo.expiryHeight.toString(),
            ),
            BullDetailsTableItem(
              label: l10n.vtxoBlocksRemaining,
              displayValue: blocks,
            ),
            BullDetailsTableItem(
              label: l10n.vtxoCreated,
              displayValue: l10n.unknown,
            ),
            BullDetailsTableItem(
              label: l10n.id,
              displayValue: vtxo.id,
              copyValue: vtxo.id,
              copiedMessage: l10n.copied,
            ),
            BullDetailsTableItem(
              label: l10n.vtxoAnchor,
              displayValue: vtxo.anchor ?? l10n.unknown,
              copyValue: vtxo.anchor,
              copiedMessage: l10n.copied,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final snapshot = widget.snapshot;
    final eligible = _eligible(snapshot);
    final selection = _selected.intersection(eligible);
    final details = _uniqueVtxo(_detailsId);
    final values = snapshot.vtxos.where((v) => _matches(v, _filter));
    final total = snapshot.vtxos.fold<BigInt>(
      BigInt.zero,
      (sum, vtxo) => sum + vtxo.amount.value,
    );
    return BullScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(BullSpacing.md),
                child: details != null
                    ? _details(context, details)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          BullTopBar(
                            title: l10n.vtxos,
                            onBack: () => Navigator.pop(context),
                          ),
                          if (snapshot.stale) BullInfoBar(message: l10n.stale),
                          if (!_current(snapshot))
                            BullInfoBar(message: l10n.unknown),
                          if (snapshot.vtxos.isEmpty && _current(snapshot))
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: BullSpacing.xxl,
                              ),
                              child: Column(
                                children: [
                                  BullIcon(
                                    BullIcons.accountBalanceWallet,
                                    size: 48,
                                    color: context.bull.textMuted,
                                  ),
                                  const Gap(BullSpacing.lg),
                                  BullText(
                                    l10n.vtxoEmptyTitle,
                                    role: BullTextRole.subtitle,
                                    textAlign: TextAlign.center,
                                  ),
                                  const Gap(BullSpacing.sm),
                                  BullText(
                                    l10n.vtxoEmptyBody,
                                    role: BullTextRole.body,
                                    textAlign: TextAlign.center,
                                    color: context.bull.textMuted,
                                  ),
                                  const Gap(BullSpacing.sm),
                                  BullText(
                                    l10n.empty,
                                    role: BullTextRole.caption,
                                    textAlign: TextAlign.center,
                                    color: context.bull.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          if (snapshot.vtxos.isNotEmpty) ...[
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
                                    l10n.vtxoTotal,
                                    role: BullTextRole.label,
                                    color: context.bull.textMuted,
                                  ),
                                  const Gap(BullSpacing.xs),
                                  BullText(
                                    formatArkObservedSats(
                                      context,
                                      _current(snapshot) ? Sats(total) : null,
                                    ),
                                    role: BullTextRole.headline,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  const Gap(BullSpacing.xs),
                                  BullText(
                                    '${snapshot.vtxos.length} ${l10n.vtxoCount}',
                                    role: BullTextRole.label,
                                    color: context.bull.textMuted,
                                  ),
                                ],
                              ),
                            ),
                            const Gap(BullSpacing.md),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final filter in _VtxoFilter.values)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: BullSpacing.sm,
                                      ),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          minHeight: 44,
                                        ),
                                        child: BullFilterChip.selectable(
                                          label:
                                              '${switch (filter) {
                                                _VtxoFilter.all => l10n.vtxoAll,
                                                _VtxoFilter.spendable => l10n.spendableState,
                                                _VtxoFilter.locked => l10n.lockedState,
                                                _VtxoFilter.expired => l10n.vtxoExpired,
                                              }} ${snapshot.vtxos.where((v) => _matches(v, filter)).length}',
                                          selected: _filter == filter,
                                          selectionColor: context.bull.text,
                                          onSelected: (_) =>
                                              setState(() => _filter = filter),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Gap(BullSpacing.md),
                            if (values.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(BullSpacing.lg),
                                child: BullText(
                                  l10n.vtxoNoMatches,
                                  role: BullTextRole.body,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            for (final v in values)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: BullSpacing.xs,
                                ),
                                child: BullBorderedTile(
                                  onTap: eligible.contains(v.id)
                                      ? () => _toggle(snapshot.account, v.id)
                                      : null,
                                  backgroundColor: _selected.contains(v.id)
                                      ? context.bull.surfaceContainer
                                      : context.bull.surface,
                                  child: Row(
                                    children: [
                                      if (_selected.contains(v.id)) ...[
                                        BullIcon(
                                          BullIcons.check,
                                          color: context.bull.text,
                                        ),
                                        const Gap(BullSpacing.sm),
                                      ],
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            BullText(
                                              formatArkObservedSats(
                                                context,
                                                v.amount,
                                              ),
                                              role: BullTextRole.body,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            BullText(
                                              _expired(v)
                                                  ? l10n.vtxoExpired
                                                  : _state(context, v),
                                              role: BullTextRole.caption,
                                              color: context.bull.textMuted,
                                            ),
                                            BullText(
                                              v.id,
                                              role: BullTextRole.caption,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              color: context.bull.textMuted,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Semantics(
                                        button: true,
                                        label: '${l10n.vtxoDetails}: ${v.id}',
                                        child: GestureDetector(
                                          key: ValueKey('vtxo-details-${v.id}'),
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => _openDetails(
                                            snapshot.account,
                                            v.id,
                                          ),
                                          child: SizedBox(
                                            width: 48,
                                            height: 48,
                                            child: Center(
                                              child: BullIcon(
                                                BullIcons.chevronRight,
                                                color: context.bull.textMuted,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(BullSpacing.md),
              child: BullButton.big(
                label: l10n.renew,
                onPressed: () => _review(snapshot.account),
                disabled: selection.isEmpty,
                bgColor: context.bull.text,
                textColor: context.bull.background,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
