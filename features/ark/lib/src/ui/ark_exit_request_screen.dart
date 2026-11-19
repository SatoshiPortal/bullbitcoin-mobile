import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:primitives/primitives.dart';

import '../presentation/ark_l10n.dart';
import 'ark_amount.dart';

/// Collects one foreground intent; the native quote revalidates all authority.
class ArkExitRequestScreen extends StatefulWidget {
  final ArkSnapshot snapshot;
  final List<String>? claimIds;
  final ValueChanged<ArkQuoteRequest> onReview;
  final int reviewCycle;
  const ArkExitRequestScreen({
    super.key,
    required this.snapshot,
    required this.onReview,
    this.claimIds,
    this.reviewCycle = 0,
  });
  @override
  State<ArkExitRequestScreen> createState() => _ArkExitRequestScreenState();
}

class _ArkExitRequestScreenState extends State<ArkExitRequestScreen> {
  String _destination = '', _rate = '', _maximum = '';
  bool _consumed = false;
  bool _selectedOnly = false;
  final Set<String> _selected = {};
  int _revision = 0;

  BigInt? _positive(String raw, BigInt maximum) {
    if (!RegExp(r'^[0-9]+$').hasMatch(raw)) return null;
    final value = BigInt.tryParse(raw);
    return value != null && value > BigInt.zero && value <= maximum
        ? value
        : null;
  }

  List<String> get _ids =>
      widget.claimIds ??
      [
        for (final vtxo in widget.snapshot.vtxos)
          if (vtxo.state == ArkVtxoState.spendable &&
              !vtxo.pendingRound &&
              (!_selectedOnly || _selected.contains(vtxo.id)))
            vtxo.id,
      ];

  bool _current(ArkExitRequestScreen rendered, int revision) =>
      mounted &&
      !_consumed &&
      identical(rendered, widget) &&
      revision == _revision;

  ArkQuoteRequest? _request() {
    final snapshot = widget.snapshot;
    final ids = _ids;
    final maximum = _positive(_maximum, BigInt.from(2100000000000000));
    if (snapshot.stale ||
        snapshot.tipHeight == null ||
        ids.isEmpty ||
        ids.toSet().length != ids.length ||
        maximum == null ||
        _destination.trim().isEmpty) {
      return null;
    }
    if (widget.claimIds != null) {
      if (!ids.every(
        (id) =>
            snapshot.exitDetails
                .where(
                  (exit) =>
                      exit.id == id && exit.status == ArkExitStatus.claimable,
                )
                .length ==
            1,
      )) {
        return null;
      }
      return ArkQuoteRequest.claim(
        ids: ids,
        destination: _destination.trim(),
        maxFee: Sats(maximum),
      );
    }
    final rate = _positive(_rate, BigInt.from(9007199254740991));
    if (rate == null || !snapshot.vtxoInventoryComplete) {
      return null;
    }
    return ArkQuoteRequest.emergencyExit(
      ids: ids,
      destination: _destination.trim(),
      feeRate: FeeRate(rate.toDouble()),
      maxClaimFee: Sats(maximum),
    );
  }

  void _edit(ArkExitRequestScreen rendered, int revision, VoidCallback change) {
    if (_current(rendered, revision)) {
      setState(() {
        change();
        ++_revision;
      });
    }
  }

  void _review(ArkExitRequestScreen rendered, int revision) {
    if (!_current(rendered, revision)) return;
    final request = _request();
    if (request == null) return;
    setState(() => _consumed = true);
    rendered.onReview(request);
  }

  @override
  void didUpdateWidget(ArkExitRequestScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.account == widget.snapshot.account &&
        widget.reviewCycle > oldWidget.reviewCycle) {
      _consumed = false;
      ++_revision;
    }
    if (oldWidget.snapshot.account != widget.snapshot.account) {
      _destination = _rate = _maximum = '';
      _selectedOnly = false;
      _selected.clear();
      ++_revision;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final rendered = widget;
    final revision = _revision;
    final ids = _ids;
    final values = widget.claimIds == null
        ? widget.snapshot.vtxos
              .where((vtxo) => ids.contains(vtxo.id))
              .map((vtxo) => vtxo.amount.value)
        : widget.snapshot.exitDetails
              .where((exit) => ids.contains(exit.id))
              .map((exit) => exit.amount.value);
    final amount = Sats(values.fold(BigInt.zero, (sum, value) => sum + value));
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
            label: widget.claimIds == null ? l10n.exitReviewTitle : l10n.review,
            disabled: _consumed || _request() == null,
            onPressed: () => _review(rendered, revision),
            bgColor: context.bull.inverseSurface,
            textColor: context.bull.surface,
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
                title: widget.claimIds == null
                    ? l10n.newEmergencyExit
                    : l10n.exits,
                titleWidget: BullText(
                  widget.claimIds == null ? l10n.newEmergencyExit : l10n.exits,
                  role: BullTextRole.subtitle,
                ),
                onBack: () => Navigator.pop(context),
              ),
              if (widget.claimIds != null)
                BullInfoBar(message: l10n.foregroundExit),
              if (widget.claimIds == null) ...[
                BullText(
                  l10n.exitChooseBody,
                  role: BullTextRole.body,
                  color: context.bull.textMuted,
                ),
                const Gap(BullSpacing.md),
                BullSegmented(
                  items: {l10n.exitAllEligible, l10n.exitSelected},
                  initialValue: _selectedOnly
                      ? l10n.exitSelected
                      : l10n.exitAllEligible,
                  onSelected: (value) => _edit(
                    rendered,
                    revision,
                    () => _selectedOnly = value == l10n.exitSelected,
                  ),
                ),
                const Gap(BullSpacing.sm),
                if (_selectedOnly)
                  for (final vtxo in widget.snapshot.vtxos)
                    if (vtxo.state == ArkVtxoState.spendable &&
                        !vtxo.pendingRound)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: BullSpacing.sm,
                        ),
                        color: context.bull.surface,
                        child: Row(
                          children: [
                            BullCheckbox(
                              checked: _selected.contains(vtxo.id),
                              disabled: _consumed,
                              onChanged: (checked) =>
                                  _edit(rendered, revision, () {
                                    if (checked) {
                                      _selected.add(vtxo.id);
                                    } else {
                                      _selected.remove(vtxo.id);
                                    }
                                  }),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BullText(
                                    formatArkObservedSats(context, vtxo.amount),
                                    role: BullTextRole.body,
                                  ),
                                  BullText(
                                    vtxo.id,
                                    role: BullTextRole.caption,
                                    color: context.bull.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ],
              const Gap(BullSpacing.md),
              BullDetailsTable(
                items: [
                  BullDetailsTableItem(
                    label: widget.claimIds != null || _selectedOnly
                        ? l10n.exitSelected
                        : l10n.exitAllEligible,
                    displayValue: ids.length.toString(),
                  ),
                  BullDetailsTableItem(
                    label: l10n.exitAvailableValue,
                    displayValue: formatArkObservedSats(
                      context,
                      widget.snapshot.stale ||
                              (widget.claimIds == null &&
                                  !widget.snapshot.vtxoInventoryComplete)
                          ? null
                          : amount,
                    ),
                  ),
                ],
              ),
              BullInfoBar(message: l10n.exitFeesAfterReview),
              const Gap(BullSpacing.md),
              if (widget.claimIds != null)
                for (final id in ids) BullText(id, role: BullTextRole.caption),
              const Gap(BullSpacing.sm),
              if (widget.claimIds == null)
                BullText(l10n.claimDestination, role: BullTextRole.label),
              BullInputText(
                value: _destination,
                hint: l10n.claimDestination,
                disabled: _consumed,
                onChanged: (value) =>
                    _edit(rendered, revision, () => _destination = value),
              ),
              if (widget.claimIds == null) ...[
                const Gap(BullSpacing.md),
                BullText(l10n.exitProgressFeeRate, role: BullTextRole.label),
                BullInputText(
                  value: _rate,
                  hint: l10n.exitProgressFeeRate,
                  digitsOnly: true,
                  onlyNumbers: true,
                  disabled: _consumed,
                  onChanged: (value) =>
                      _edit(rendered, revision, () => _rate = value),
                ),
              ],
              if (widget.claimIds == null) ...[
                const Gap(BullSpacing.md),
                BullText(l10n.exitMaximumClaimFee, role: BullTextRole.label),
              ],
              BullInputText(
                value: _maximum,
                hint: l10n.exitMaximumClaimFee,
                digitsOnly: true,
                onlyNumbers: true,
                disabled: _consumed,
                onChanged: (value) =>
                    _edit(rendered, revision, () => _maximum = value),
              ),
              if (widget.claimIds == null) ...[
                const Gap(BullSpacing.md),
                BullInfoBar(message: l10n.foregroundExit),
                BullInfoBar(message: l10n.exitProgressReviewWarning),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
