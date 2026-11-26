import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:primitives/primitives.dart';

import '../domain/ark_failure.dart';
import '../presentation/ark_failure_l10n.dart';
import '../presentation/ark_l10n.dart';
import '../presentation/ark_operation_cubit.dart';
import 'ark_amount.dart';
import 'ark_hold_button.dart';
import 'ark_summary_box.dart';

/// How a start sheet closed. A dismissed sheet returns null.
enum ArkExitOutcome { started, uncertain }

enum _Destination { secureBitcoin, another }

/// Starts an emergency exit: where the funds go, the quote for exactly that
/// destination, and a hold to confirm it.
///
/// Every destination gets its own quote, and only a quote for the destination
/// on screen can be confirmed. The sheet owns its quotes and closes them.
class ArkExitStartSheet extends StatefulWidget {
  final ArkAccountId account;
  final List<String> ids;
  final bool allEligible;

  /// The destination-less estimate from the previous screen, shown until the
  /// quote for the chosen destination arrives.
  final ArkQuote estimate;
  final ArkOperationCubit Function(ArkQuoteRequest request) quote;

  /// The Secure Bitcoin wallet's next address; without it the funds can only
  /// go to an address the user types.
  final Future<Result<String, ArkFailure>> Function()? secureBitcoinAddress;

  /// Makes sure the reserve can pay the fresh quote's fees, topping it up
  /// from Secure Bitcoin; a failure means the exit must not start.
  final Future<Result<ArkExitReserveFunding, ArkFailure>> Function(
    ArkQuote quote,
  )?
  fundFees;

  final Future<Result<String?, ArkFailure>> Function()? savedDestination;

  const ArkExitStartSheet({
    super.key,
    required this.account,
    required this.ids,
    required this.allEligible,
    required this.estimate,
    required this.quote,
    this.secureBitcoinAddress,
    this.fundFees,
    this.savedDestination,
  });

  static Future<ArkExitOutcome?> show(
    BuildContext context, {
    required ArkAccountId account,
    required List<String> ids,
    required bool allEligible,
    required ArkQuote estimate,
    required ArkOperationCubit Function(ArkQuoteRequest request) quote,
    Future<Result<String, ArkFailure>> Function()? secureBitcoinAddress,
    Future<Result<String?, ArkFailure>> Function()? savedDestination,
    Future<Result<ArkExitReserveFunding, ArkFailure>> Function(ArkQuote quote)?
    fundFees,
  }) => BullBottomSheet.show<ArkExitOutcome>(
    context: context,
    avoidKeyboard: true,
    child: ArkExitStartSheet(
      account: account,
      ids: ids,
      allEligible: allEligible,
      estimate: estimate,
      quote: quote,
      secureBitcoinAddress: secureBitcoinAddress,
      fundFees: fundFees,
      savedDestination: savedDestination,
    ),
  );

  @override
  State<ArkExitStartSheet> createState() => _ArkExitStartSheetState();
}

class _ArkExitStartSheetState extends State<ArkExitStartSheet> {
  late _Destination _choice;
  String? _secureAddress;
  bool _secureUnavailable = false;
  bool _destinationSaved = false;
  String _another = '';
  ArkOperationCubit? _cubit;
  StreamSubscription<ArkOperationState>? _changes;
  String? _quotedFor;
  Timer? _typing;

  /// Set by any pop of this sheet: Cancel, the scrim, a drag or an outcome.
  bool _dismissed = false;

  /// Re-pricing the exit right before it starts.
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _choice = widget.secureBitcoinAddress == null
        ? _Destination.another
        : _Destination.secureBitcoin;
    unawaited(_loadSecureAddress());
  }

  @override
  void dispose() {
    _typing?.cancel();
    _drop();
    super.dispose();
  }

  Future<void> _loadSecureAddress() async {
    if (widget.savedDestination case final read?) {
      final result = await read();
      if (!mounted) return;
      if (result case Ok(value: final String destination)) {
        setState(() {
          _choice = _Destination.another;
          _another = destination;
          _destinationSaved = true;
        });
        _requote();
        return;
      }
    }
    final read = widget.secureBitcoinAddress;
    if (read == null) return;
    final result = await read();
    if (!mounted) return;
    setState(() {
      switch (result) {
        case Ok(:final value):
          _secureAddress = value;
        case Err():
          _secureUnavailable = true;
      }
    });
    _requote();
  }

  String? get _destination => switch (_choice) {
    _Destination.secureBitcoin => _secureAddress,
    _Destination.another => _another.trim().isEmpty ? null : _another.trim(),
  };

  void _choose(_Destination choice) {
    if (_choice == choice || _busy || _destinationSaved) return;
    setState(() => _choice = choice);
    _requote();
  }

  void _typed(String value) {
    if (_destinationSaved) return;
    _another = value;
    _typing?.cancel();
    // Quote once the address stops changing, not on every keystroke.
    _typing = Timer(const Duration(milliseconds: 500), _requote);
    setState(() {});
  }

  /// Replaces the quote with one for the destination now on screen.
  void _requote() {
    if (!mounted) return;
    final destination = _destination;
    if (_cubit != null && destination == _quotedFor) return;
    _drop();
    _quotedFor = destination;
    if (destination != null) {
      final cubit = widget.quote(
        ArkQuoteRequest.emergencyExit(
          ids: widget.ids,
          destination: destination,
        ),
      );
      _cubit = cubit;
      _changes = cubit.stream.listen(_changed);
      unawaited(cubit.load());
    }
    setState(() {});
  }

  void _drop() {
    unawaited(_changes?.cancel());
    unawaited(_cubit?.close());
    _changes = null;
    _cubit = null;
  }

  void _changed(ArkOperationState state) {
    if (!mounted) return;
    switch (state) {
      case ArkOperationSubmitted():
        _close(ArkExitOutcome.started);
      case ArkOperationUncertain():
        _close(ArkExitOutcome.uncertain);
      default:
        setState(() {});
    }
  }

  /// Pops this sheet only while it is still the top route. Once dismissed it
  /// keeps rendering through its exit animation, and a second pop would close
  /// the page underneath.
  void _close(ArkExitOutcome? outcome) {
    if (!mounted || _dismissed) return;
    _dismissed = true;
    Navigator.pop(context, outcome);
  }

  bool get _busy => _starting || _cubit?.state is ArkOperationSubmitting;

  /// Only an exit quote for exactly these VTXOs, on this account, to the
  /// destination on screen can be confirmed.
  bool _matches(ArkQuote quote) =>
      quote.kind == ArkOperationKind.emergencyExit &&
      quote.account == widget.account &&
      quote.destination != null &&
      quote.destination == _destination &&
      quote.destination == _quotedFor &&
      quote.selectedIds.toSet().containsAll(widget.ids) &&
      widget.ids.toSet().containsAll(quote.selectedIds);

  ArkQuote? get _ready => switch (_cubit?.state) {
    ArkOperationReview(:final quote) when _matches(quote) => quote,
    _ => null,
  };

  bool _withinReviewedTerms(ArkQuote candidate, ArkQuote reviewed) =>
      candidate.chainSource == reviewed.chainSource &&
      candidate.configGeneration == reviewed.configGeneration &&
      candidate.fee.value <= reviewed.fee.value &&
      candidate.net.value >= reviewed.net.value;

  /// Starts the exit with a fresh quote for the reviewed destination.
  Future<void> _start() async {
    final cubit = _cubit;
    final state = cubit?.state;
    if (cubit == null ||
        cubit.isClosed ||
        state is! ArkOperationReview ||
        !identical(state.quote, _ready)) {
      return;
    }
    // A quote is bound to the block it was priced at, and confirming refuses
    // an older one as an unknown outcome. The sheet may have been open for
    // blocks: price again now, for the same VTXOs and destination, and start
    // that fresh quote at once.
    setState(() {
      _starting = true;
      _fundFailure = null;
    });
    await cubit.load();
    if (!mounted) return;
    final fresh = cubit.state;
    if (cubit.isClosed ||
        fresh is! ArkOperationReview ||
        !identical(fresh.quote, _ready) ||
        !_withinReviewedTerms(fresh.quote, state.quote)) {
      setState(() => _starting = false);
      return; // A refused re-quote shows its failure; nothing started.
    }
    var confirmation = cubit;
    if (widget.fundFees case final fund?) {
      final funded = await fund(fresh.quote);
      if (!mounted) return;
      switch (funded) {
        case Err(:final failure):
          setState(() {
            _starting = false;
            _fundFailure = failure;
          });
          return;
        case Ok(:final value):
          if (!identical(_cubit, cubit) || !_matches(fresh.quote)) {
            setState(() => _starting = false);
            return;
          }
          _drop();
          confirmation = widget.quote(
            ArkQuoteRequest.emergencyExit(
              ids: fresh.quote.selectedIds,
              destination: fresh.quote.destination,
              feeRate: fresh.quote.feeRate,
              maxClaimFee: fresh.quote.maxClaimFee,
              reserveFunding: value,
            ),
          );
          _cubit = confirmation;
          _changes = confirmation.stream.listen(_changed);
          await confirmation.load();
          if (!mounted) return;
      }
    }
    setState(() => _starting = false);
    if (confirmation.isClosed ||
        !identical(_cubit, confirmation) ||
        confirmation.state is! ArkOperationReview) {
      return;
    }
    final reviewed = _ready;
    if (reviewed == null || !_withinReviewedTerms(reviewed, fresh.quote)) {
      return;
    }
    unawaited(confirmation.confirm());
  }

  /// Why the fees could not be covered; the exit did not start.
  ArkFailure? _fundFailure;

  String _shortAddress(String address) => address.length <= 16
      ? address
      : '${address.substring(0, 8)}…${address.substring(address.length - 5)}';

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final colors = context.bull;
    final state = _cubit?.state;
    final ready = _ready;
    final shown = ready ?? widget.estimate;
    final loading =
        _starting ||
        state is ArkOperationLoading ||
        state is ArkOperationSubmitting ||
        (_choice == _Destination.secureBitcoin &&
            _secureAddress == null &&
            !_secureUnavailable);
    final secureSubtitle = _secureAddress != null
        ? _shortAddress(_secureAddress ?? '')
        : _secureUnavailable
        ? l10n.exitAddressUnavailable
        : null;
    return PopScope(
      canPop: !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _dismissed = true;
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BullSpacing.md,
          BullSpacing.sm,
          BullSpacing.md,
          BullSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(context.bullShapes.dot),
                ),
              ),
            ),
            const Gap(BullSpacing.md),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      namesRoute: true,
                      child: BullText(
                        l10n.startEmergencyExit,
                        role: BullTextRole.subtitle,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(BullSpacing.sm),
                    BullFadingLinearProgress(
                      height: 3,
                      trigger: loading,
                      backgroundColor: colors.background,
                    ),
                    const Gap(BullSpacing.xs),
                    ArkSummaryBox(
                      rows: [
                        (
                          label: widget.allEligible
                              ? l10n.exitSummaryAll(widget.ids.length)
                              : l10n.exitSummarySelected(widget.ids.length),
                          value: formatArkSats(context, shown.amount),
                        ),
                        (
                          label: l10n.exitBroadcastFees,
                          value: formatArkSats(context, shown.fee),
                        ),
                        (
                          label: l10n.exitClaimFee,
                          value: formatArkObservedSats(context, shown.claimFee),
                        ),
                        (
                          label: l10n.exitEstimatedToReceive,
                          value: formatArkSats(context, shown.net),
                        ),
                      ],
                    ),
                    const Gap(BullSpacing.md),
                    Semantics(
                      header: true,
                      child: BullText(
                        l10n.exitSendFundsTo,
                        role: BullTextRole.body,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(BullSpacing.xs),
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(
                          context.bullShapes.card,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.secureBitcoinAddress != null &&
                              !_destinationSaved) ...[
                            BullPickerRow(
                              label: l10n.exitSecureBitcoinWallet,
                              subtitle: secureSubtitle,
                              selected: _choice == _Destination.secureBitcoin,
                              onPressed: _busy
                                  ? null
                                  : () => _choose(_Destination.secureBitcoin),
                            ),
                            Container(height: 1, color: colors.outlineVariant),
                          ],
                          BullPickerRow(
                            label: l10n.exitAnotherWallet,
                            selected: _choice == _Destination.another,
                            onPressed: _busy
                                ? null
                                : () => _choose(_Destination.another),
                          ),
                        ],
                      ),
                    ),
                    // Below the choices, on its own: the selected row's
                    // tint never runs into it.
                    if (_choice == _Destination.another) ...[
                      const Gap(BullSpacing.sm),
                      BullInputText(
                        value: _another,
                        hint: l10n.exitBitcoinAddress,
                        disabled: _busy || _destinationSaved,
                        autocorrect: false,
                        enableSuggestions: false,
                        onChanged: _typed,
                      ),
                    ],
                    // Why it did not start, in red as the app shows it.
                    if (switch (state) {
                          ArkOperationFailed(:final failure) => failure,
                          _ => _fundFailure,
                        }
                        case final failure?) ...[
                      const Gap(BullSpacing.sm),
                      Semantics(
                        liveRegion: true,
                        child: BullText(
                          failure.toTranslated(context),
                          role: BullTextRole.body,
                          fontWeight: FontWeight.w500,
                          color: colors.error,
                          textAlign: TextAlign.center,
                          maxLines: 5,
                        ),
                      ),
                    ],
                    const Gap(BullSpacing.sm),
                    BullText(
                      l10n.exitStartNote,
                      role: BullTextRole.label,
                      color: colors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            const Gap(BullSpacing.md),
            if (state is ArkOperationFailed)
              BullButton.big(
                label: l10n.retry,
                onPressed: () {
                  final cubit = _cubit;
                  if (cubit != null && !cubit.isClosed) {
                    unawaited(cubit.load());
                  }
                },
                bgColor: colors.inverseSurface,
                textColor: colors.surface,
              )
            else
              ArkHoldButton(
                label: l10n.exitHoldToStart,
                holdingLabel: l10n.exitKeepHolding,
                hint: l10n.exitHoldHint,
                releasedHint: l10n.exitHoldReleased,
                onConfirmed: ready == null || _busy
                    ? null
                    : () => unawaited(_start()),
              ),
            const Gap(BullSpacing.xs),
            BullButton.big(
              label: l10n.exitCancel,
              onPressed: () => _close(null),
              disabled: _busy,
              bgColor: colors.surface,
              textColor: colors.text,
              outlined: true,
              borderColor: colors.border,
            ),
          ],
        ),
      ),
    );
  }
}
