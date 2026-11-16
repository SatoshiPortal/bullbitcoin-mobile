import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';

import '../presentation/ark_l10n.dart';

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

  @override
  void didUpdateWidget(ArkVtxosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.account != widget.snapshot.account) {
      _selected.clear();
    }
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

  void _review(ArkAccountId account) {
    if (widget.snapshot.account != account) return;
    final ids = _selected.intersection(_eligible(widget.snapshot));
    if (ids.isNotEmpty) widget.onRenew(List.unmodifiable(ids));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final snapshot = widget.snapshot;
    final eligible = _eligible(snapshot);
    final selection = _selected.intersection(eligible);
    return BullScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BullSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BullTopBar(
                title: l10n.vtxos,
                onBack: () => Navigator.pop(context),
              ),
              if (snapshot.stale) BullInfoBar(message: l10n.stale),
              if (!_current(snapshot)) BullInfoBar(message: l10n.unknown),
              if (_current(snapshot) && snapshot.vtxos.isEmpty)
                BullText(l10n.empty, style: null),
              for (final v in snapshot.vtxos)
                Padding(
                  padding: const EdgeInsets.only(bottom: BullSpacing.xs),
                  child: BullBorderedTile(
                    onTap: eligible.contains(v.id)
                        ? () => _toggle(snapshot.account, v.id)
                        : null,
                    backgroundColor: _selected.contains(v.id)
                        ? context.bull.surface
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selected.contains(v.id))
                          const BullIcon(BullIcons.check),
                        BullDetailsTable(
                          items: [
                            BullDetailsTableItem(
                              label: l10n.amount,
                              displayValue: v.amount.toString(),
                            ),
                            BullDetailsTableItem(
                              label: l10n.id,
                              displayValue: v.id,
                              copyValue: v.id,
                              copiedMessage: l10n.copied,
                            ),
                            BullDetailsTableItem(
                              label: l10n.expiryHeight,
                              displayValue: v.expiryHeight.toString(),
                            ),
                            BullDetailsTableItem(
                              label: l10n.state,
                              displayValue: switch (v.state) {
                                ArkVtxoState.spendable => l10n.spendableState,
                                ArkVtxoState.locked => l10n.lockedState,
                                ArkVtxoState.spent => l10n.spentState,
                                ArkVtxoState.exited => l10n.exitedState,
                                ArkVtxoState.unknown => l10n.unknownState,
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              BullButton.big(
                label: l10n.renew,
                onPressed: () => _review(snapshot.account),
                disabled: selection.isEmpty,
                bgColor: context.bull.primary,
                textColor: context.bull.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
