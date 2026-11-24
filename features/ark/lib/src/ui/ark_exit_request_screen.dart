import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:primitives/primitives.dart';

import '../domain/ark_failure.dart';
import '../presentation/ark_failure_l10n.dart';
import '../presentation/ark_l10n.dart';
import '../presentation/ark_operation_cubit.dart';
import 'ark_amount.dart';
import 'ark_exit_start_sheet.dart';

/// Collects one foreground intent; the native quote revalidates all authority.
class ArkExitRequestScreen extends StatefulWidget {
  final ArkSnapshot snapshot;
  final List<String>? claimIds;

  /// Reviews a claim on its own screen.
  final ValueChanged<ArkQuoteRequest> onReview;

  /// Quotes an emergency exit: an estimate here, then one per destination in
  /// the start sheet. Without it an exit cannot be priced or started.
  final ArkOperationCubit Function(ArkQuoteRequest request)? quote;

  /// The Secure Bitcoin wallet's next address, offered as the destination.
  final Future<Result<String, ArkFailure>> Function()? secureBitcoinAddress;

  /// An exit was started, or may have been.
  final ValueChanged<ArkExitOutcome>? onStarted;

  /// Funds the reserve for a fresh exit quote before it starts.
  final Future<Result<void, ArkFailure>> Function(ArkQuote quote)? fundFees;

  const ArkExitRequestScreen({
    super.key,
    required this.snapshot,
    required this.onReview,
    this.claimIds,
    this.quote,
    this.secureBitcoinAddress,
    this.onStarted,
    this.fundFees,
  });

  @override
  State<ArkExitRequestScreen> createState() => _ArkExitRequestScreenState();
}

class _ArkExitRequestScreenState extends State<ArkExitRequestScreen> {
  String _destination = '', _maximum = '';
  bool _consumed = false;
  bool _selectedOnly = false;
  final Set<String> _selected = {};
  int _revision = 0;
  ArkOperationCubit? _estimate;
  StreamSubscription<ArkOperationState>? _estimateChanges;
  String? _estimatedFor;

  @override
  void initState() {
    super.initState();
    _reestimate();
  }

  @override
  void dispose() {
    _dropEstimate();
    super.dispose();
  }

  void _dropEstimate() {
    unawaited(_estimateChanges?.cancel());
    unawaited(_estimate?.close());
    _estimateChanges = null;
    _estimate = null;
  }

  /// Prices the exit of the VTXOs now chosen, once per distinct choice.
  void _reestimate() {
    final quote = widget.quote;
    final snapshot = widget.snapshot;
    final ids = _ids;
    final key = '${snapshot.account.canonical}|${ids.join(',')}';
    if (widget.claimIds != null || quote == null) return;
    if (_estimate != null && key == _estimatedFor) return;
    _dropEstimate();
    _estimatedFor = key;
    if (ids.isEmpty ||
        snapshot.stale ||
        snapshot.tipHeight == null ||
        !snapshot.vtxoInventoryComplete) {
      return;
    }
    final cubit = quote(ArkQuoteRequest.emergencyExit(ids: ids));
    _estimate = cubit;
    _estimateChanges = cubit.stream.listen((_) {
      if (mounted) setState(() {});
    });
    unawaited(cubit.load());
  }

  /// The estimate for exactly the VTXOs now chosen on this account.
  ArkQuote? get _estimated {
    final ids = _ids;
    return switch (_estimate?.state) {
      ArkOperationReview(:final quote)
          when quote.kind == ArkOperationKind.emergencyExit &&
              quote.account == widget.snapshot.account &&
              quote.selectedIds.toSet().containsAll(ids) &&
              ids.toSet().containsAll(quote.selectedIds) =>
        quote,
      _ => null,
    };
  }

  BigInt? _positive(String raw, BigInt maximum) {
    if (!RegExp(r'^[0-9]+$').hasMatch(raw)) return null;
    final value = BigInt.tryParse(raw);
    return value != null && value > BigInt.zero && value <= maximum
        ? value
        : null;
  }

  Iterable<ArkVtxo> get _eligible => widget.snapshot.vtxos.where(
    (vtxo) => vtxo.state == ArkVtxoState.spendable && !vtxo.pendingRound,
  );

  List<String> get _ids =>
      widget.claimIds ??
      [
        for (final vtxo in _eligible)
          if (!_selectedOnly || _selected.contains(vtxo.id)) vtxo.id,
      ];

  bool _current(ArkExitRequestScreen rendered, int revision) =>
      mounted &&
      !_consumed &&
      identical(rendered, widget) &&
      revision == _revision;

  /// A claim request; exits are quoted by [_reestimate] and the start sheet.
  ArkQuoteRequest? _request() {
    final snapshot = widget.snapshot;
    final ids = _ids;
    final maximum = _positive(_maximum, BigInt.from(2100000000000000));
    if (widget.claimIds == null ||
        snapshot.stale ||
        snapshot.tipHeight == null ||
        ids.isEmpty ||
        ids.toSet().length != ids.length ||
        maximum == null ||
        _destination.trim().isEmpty) {
      return null;
    }
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

  void _edit(ArkExitRequestScreen rendered, int revision, VoidCallback change) {
    if (_current(rendered, revision)) {
      setState(() {
        change();
        ++_revision;
      });
      _reestimate();
    }
  }

  void _review(ArkExitRequestScreen rendered, int revision) {
    if (!_current(rendered, revision)) return;
    final request = _request();
    if (request == null) return;
    setState(() => _consumed = true);
    rendered.onReview(request);
  }

  /// The start sheet picks the destination, quotes it and holds to start.
  Future<void> _openStart(ArkExitRequestScreen rendered, int revision) async {
    final estimate = _estimated;
    final quote = rendered.quote;
    if (!_current(rendered, revision) || estimate == null || quote == null) {
      return;
    }
    final outcome = await ArkExitStartSheet.show(
      context,
      account: rendered.snapshot.account,
      ids: _ids,
      allEligible: !_selectedOnly,
      estimate: estimate,
      quote: quote,
      secureBitcoinAddress: rendered.secureBitcoinAddress,
      fundFees: rendered.fundFees,
    );
    if (outcome == null || !_current(rendered, revision)) return;
    setState(() => _consumed = true);
    rendered.onStarted?.call(outcome);
  }

  /// Unknown stays unknown: stale or incomplete inventories have no total.
  Sats? _value() {
    final ids = _ids;
    if (widget.snapshot.stale ||
        (widget.claimIds == null && !widget.snapshot.vtxoInventoryComplete)) {
      return null;
    }
    final values = widget.claimIds == null
        ? widget.snapshot.vtxos
              .where((vtxo) => ids.contains(vtxo.id))
              .map((vtxo) => vtxo.amount.value)
        : widget.snapshot.exitDetails
              .where((exit) => ids.contains(exit.id))
              .map((exit) => exit.amount.value);
    return Sats(values.fold(BigInt.zero, (sum, value) => sum + value));
  }

  @override
  void didUpdateWidget(ArkExitRequestScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.account != widget.snapshot.account) {
      _destination = _maximum = '';
      _selectedOnly = false;
      _selected.clear();
      ++_revision;
    }
    if (!identical(oldWidget.snapshot, widget.snapshot)) {
      _estimatedFor = null;
      _reestimate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final rendered = widget;
    final revision = _revision;
    final ids = _ids;
    final claim = widget.claimIds != null;
    final ready =
        !_consumed && (claim ? _request() != null : _estimated != null);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BullButton.big(
                label: claim ? l10n.exitReviewClaim : l10n.exitReviewExit,
                disabled: !ready,
                onPressed: () => claim
                    ? _review(rendered, revision)
                    : unawaited(_openStart(rendered, revision)),
                bgColor: context.bull.inverseSurface,
                textColor: context.bull.surface,
              ),
              if (!claim && ids.isEmpty) ...[
                const Gap(BullSpacing.xs),
                BullText(
                  l10n.exitChooseAtLeastOne,
                  role: BullTextRole.caption,
                  color: context.bull.textMuted,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            BullSpacing.md,
            BullSpacing.zero,
            BullSpacing.md,
            BullSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BullTopBar(
                title: claim ? l10n.exitClaimTitle : l10n.newEmergencyExit,
                titleWidget: BullText(
                  claim ? l10n.exitClaimTitle : l10n.newEmergencyExit,
                  role: BullTextRole.title,
                ),
                onBack: () => Navigator.pop(context),
              ),
              BullText(
                claim ? l10n.exitClaimBody : l10n.exitChooseBody,
                role: BullTextRole.body,
                color: context.bull.textMuted,
              ),
              const Gap(BullSpacing.md),
              if (!claim) ...[
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
                const Gap(BullSpacing.md),
                if (_selectedOnly) ...[
                  _chooser(context, rendered, revision),
                  const Gap(BullSpacing.md),
                ],
              ],
              BullDetailsTable(
                items: [
                  BullDetailsTableItem(
                    label: claim
                        ? l10n.exitClaimCount
                        : _selectedOnly
                        ? l10n.exitSelected
                        : l10n.exitAvailableVtxos,
                    displayValue: ids.length.toString(),
                  ),
                  BullDetailsTableItem(
                    label: _selectedOnly
                        ? l10n.exitSelectedValue
                        : l10n.exitAvailableValue,
                    displayValue: formatArkObservedSats(context, _value()),
                  ),
                ],
              ),
              if (claim) ...[
                const Gap(BullSpacing.xs),
                for (final id in ids)
                  BullText(
                    id,
                    role: BullTextRole.caption,
                    color: context.bull.textMuted,
                  ),
              ],
              if (claim) ...[
                const Gap(BullSpacing.md),
                _section(context, l10n.exitSendFundsTo, [
                  BullText(
                    l10n.exitBitcoinAddress,
                    role: BullTextRole.label,
                    color: context.bull.textMuted,
                  ),
                  const Gap(BullSpacing.xxs),
                  BullInputText(
                    value: _destination,
                    hint: l10n.claimDestination,
                    disabled: _consumed,
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: (value) =>
                        _edit(rendered, revision, () => _destination = value),
                  ),
                ]),
                const Gap(BullSpacing.md),
                _section(context, l10n.exitFeesTitle, [
                  BullText(
                    l10n.exitFeesAfterReview,
                    role: BullTextRole.caption,
                    color: context.bull.textMuted,
                  ),
                  const Gap(BullSpacing.sm),
                  BullText(
                    l10n.exitMaximumClaimFee,
                    role: BullTextRole.label,
                    color: context.bull.textMuted,
                  ),
                  const Gap(BullSpacing.xxs),
                  BullInputText(
                    value: _maximum,
                    hint: l10n.exitMaximumClaimFee,
                    digitsOnly: true,
                    onlyNumbers: true,
                    disabled: _consumed,
                    onChanged: (value) =>
                        _edit(rendered, revision, () => _maximum = value),
                  ),
                ]),
              ] else ...[
                const Gap(BullSpacing.md),
                _ExitFees(state: _estimate?.state, quote: _estimated),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chooser(
    BuildContext context,
    ArkExitRequestScreen rendered,
    int revision,
  ) {
    final l10n = arkLocalizationsOf(context);
    final eligible = _eligible.toList();
    final allSelected =
        eligible.isNotEmpty && eligible.every((v) => _selected.contains(v.id));
    final tip = widget.snapshot.stale ? null : widget.snapshot.tipHeight;
    return Container(
      decoration: BoxDecoration(
        color: context.bull.surface,
        borderRadius: BorderRadius.circular(context.bullShapes.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BullSpacing.md,
              BullSpacing.xs,
              BullSpacing.xs,
              BullSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: BullText(
                      l10n.exitChooseVtxos,
                      role: BullTextRole.label,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                BullButton.small(
                  label: allSelected ? l10n.exitClearAll : l10n.exitSelectAll,
                  disabled: _consumed || eligible.isEmpty,
                  onPressed: () => _edit(rendered, revision, () {
                    if (allSelected) {
                      _selected.clear();
                    } else {
                      _selected.addAll(eligible.map((v) => v.id));
                    }
                  }),
                  bgColor: context.bull.surface,
                  textColor: context.bull.primary,
                  compact: true,
                ),
              ],
            ),
          ),
          for (final vtxo in eligible) ...[
            Container(height: 1, color: context.bull.outlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BullSpacing.xs),
              child: Row(
                children: [
                  BullCheckbox(
                    checked: _selected.contains(vtxo.id),
                    disabled: _consumed,
                    onChanged: (checked) => _edit(rendered, revision, () {
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
                          fontWeight: FontWeight.w600,
                        ),
                        if (tip != null)
                          BullText(
                            vtxo.expiryHeight > tip
                                ? l10n.exitVtxoExpiresIn(
                                    vtxo.expiryHeight - tip,
                                  )
                                : l10n.exitVtxoExpired,
                            role: BullTextRole.caption,
                            color: context.bull.textMuted,
                          ),
                      ],
                    ),
                  ),
                  const Gap(BullSpacing.xs),
                  Flexible(
                    child: BullText(
                      vtxo.id,
                      role: BullTextRole.caption,
                      color: context.bull.textMuted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Gap(BullSpacing.xs),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) =>
      Container(
        padding: const EdgeInsets.all(BullSpacing.md),
        decoration: BoxDecoration(
          color: context.bull.surface,
          borderRadius: BorderRadius.circular(context.bullShapes.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: BullText(
                title,
                role: BullTextRole.body,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(BullSpacing.sm),
            ...children,
          ],
        ),
      );
}

/// The live exit estimate: total fees, how each part is paid, and what is
/// left to receive.
class _ExitFees extends StatelessWidget {
  final ArkOperationState? state;
  final ArkQuote? quote;

  const _ExitFees({required this.state, required this.quote});

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final colors = context.bull;
    final quote = this.quote;
    final claimFee = quote?.claimFee;
    final total = quote == null || claimFee == null
        ? null
        : Sats(quote.fee.value + claimFee.value);
    return Container(
      padding: const EdgeInsets.all(BullSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(context.bullShapes.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BullText(
            l10n.exitEstimatedTotalFees,
            role: BullTextRole.label,
            color: colors.textMuted,
          ),
          const Gap(BullSpacing.xxs),
          if (total != null)
            BullText(
              formatArkSats(context, total),
              role: BullTextRole.title,
              fontWeight: FontWeight.w700,
            ),
          BullFadingLinearProgress(
            height: 2,
            trigger: state is ArkOperationLoading,
            backgroundColor: colors.surface,
          ),
          if (state case ArkOperationFailed(:final failure)) ...[
            const Gap(BullSpacing.xs),
            // Refused: why, in red, as the app shows it.
            BullText(
              failure.toTranslated(context),
              role: BullTextRole.body,
              fontWeight: FontWeight.w500,
              color: colors.error,
              textAlign: TextAlign.center,
              maxLines: 5,
            ),
          ],
          if (quote != null) ...[
            const Gap(BullSpacing.sm),
            _FeeLine(
              label: l10n.exitBroadcastFees,
              note: l10n.exitBroadcastFeesNote,
              value: formatArkSats(context, quote.fee),
            ),
            const Gap(BullSpacing.sm),
            _FeeLine(
              label: l10n.exitClaimFee,
              note: l10n.exitClaimFeeNote,
              value: formatArkObservedSats(context, claimFee),
            ),
            const Gap(BullSpacing.sm),
            Container(height: 1, color: colors.outlineVariant),
            const Gap(BullSpacing.sm),
            _FeeLine(
              label: l10n.exitEstimatedToReceive,
              value: formatArkSats(context, quote.net),
            ),
          ],
          const Gap(BullSpacing.xs),
          BullText(
            l10n.exitFeesEstimateNote,
            role: BullTextRole.caption,
            color: colors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _FeeLine extends StatelessWidget {
  final String label;
  final String? note;
  final String value;

  const _FeeLine({required this.label, required this.value, this.note});

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: BullText(
                label,
                role: BullTextRole.body,
                color: context.bull.textMuted,
              ),
            ),
            const Gap(BullSpacing.sm),
            BullText(
              value,
              role: BullTextRole.body,
              fontWeight: FontWeight.w600,
            ),
          ],
        ),
        if (note != null)
          BullText(
            note,
            role: BullTextRole.caption,
            color: context.bull.textMuted,
          ),
      ],
    );
  }
}
