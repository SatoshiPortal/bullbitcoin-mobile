import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:primitives/primitives.dart' show Sats;

import '../domain/ark_display_data_port.dart';
import '../presentation/ark_l10n.dart';
import '../presentation/ark_payment_cubit.dart';
import '../presentation/ark_failure_l10n.dart';
import '../presentation/ark_operation_status_l10n.dart';
import 'ark_amount.dart';
import 'ark_payment_progress_policy.dart';
import 'ark_review.dart';

/// The caller replaces the owner for a full config or request replacement.
/// Local navigation and scanning never request a quote or submit a payment.
class ArkPaymentScreen extends StatefulWidget {
  final ArkPaymentCubit cubit;
  final String initialDestination;
  final VoidCallback onReconcile;
  final ArkDisplayData? displayData;
  final Sats? observedSpendable;
  final Future<String?> Function()? onScan;

  /// Leaves the finished payment for the app's home; without it, closes.
  final VoidCallback? onHome;

  /// Opens this payment's details, by the reference Ark recorded for it.
  final ValueChanged<String>? onViewDetails;

  /// The app's confirmation arrow, for the review header.
  final Widget? confirmIcon;

  /// Reads once whether payment transitions play; they do when absent.
  final Future<bool> Function()? readPaymentAnimations;

  const ArkPaymentScreen({
    super.key,
    required this.cubit,
    required this.onReconcile,
    this.initialDestination = '',
    this.displayData,
    this.observedSpendable,
    this.onScan,
    this.onHome,
    this.onViewDetails,
    this.confirmIcon,
    this.readPaymentAnimations,
  });

  @override
  State<ArkPaymentScreen> createState() => _ArkPaymentScreenState();
}

class _ArkPaymentScreenState extends State<ArkPaymentScreen> {
  late String _destination;
  String _amount = '';
  late bool _amountStep;
  int _phase = 0;
  Object? _scanInFlight;
  Object? _scanIntent;
  bool _scanFailed = false;
  // The quote this screen confirmed, kept only to restate its amount once sent.
  ArkQuote? _confirmed;
  bool _showTransition = false;
  String? _transitionId;
  late StreamSubscription<ArkPaymentState> _subscription;

  bool _owns(ArkPaymentCubit owner, ArkAccountId account) =>
      mounted &&
      !owner.isClosed &&
      identical(owner, widget.cubit) &&
      account == widget.cubit.account;

  bool _current(
    ArkPaymentCubit owner,
    ArkAccountId account,
    ArkPaymentState state,
  ) => _owns(owner, account) && identical(state, owner.state);

  void _listen() {
    final owner = widget.cubit;
    final account = owner.account;
    // A new owner is a new payment: it may leave once of its own.
    _left = false;
    _subscription = owner.stream.listen((next) {
      if (_owns(owner, account)) {
        setState(() {
          if (next is ArkPaymentEditing) _showTransition = false;
        });
        _leaveIfUnsettled(next);
      }
    });
  }

  bool _left = false;

  static bool _started(ArkOperationStatus status) => switch (status) {
    ArkOperationStatus.prepared ||
    ArkOperationStatus.admitted ||
    ArkOperationStatus.pending ||
    ArkOperationStatus.succeeded => true,
    ArkOperationStatus.failed ||
    ArkOperationStatus.outcomeUnknown ||
    ArkOperationStatus.conflicted => false,
  };

  /// A payment whose outcome the app cannot tell yet has no screen of its
  /// own: the flow closes to home, Ark is refreshed, and a snackbar says so.
  void _leaveIfUnsettled(ArkPaymentState state) {
    final message = switch (state) {
      ArkPaymentUncertain() => context.loc.paymentUncertain,
      ArkPaymentSubmitted(:final operation)
          when operation.kind != ArkOperationKind.payment ||
              !_started(operation.status) =>
        operation.status == ArkOperationStatus.outcomeUnknown
            ? context.loc.paymentUncertain
            : operation.status.toTranslated(context),
      _ => null,
    };
    if (message == null || _left) return;
    _left = true;
    final owner = widget.cubit;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only for the owner that left: never a replacement's handlers.
      if (!mounted || !identical(owner, widget.cubit)) return;
      BullSnackBar.show(context, message: message);
      widget.onReconcile();
      _home();
    });
  }

  void _home() {
    final home = widget.onHome;
    if (home != null) {
      home();
    } else {
      unawaited(Navigator.maybePop(context));
    }
  }

  /// Like the app's other completed flows.
  Widget _success(ArkAccountId account, ArkOperation operation) {
    final l10n = context.loc;
    final completed =
        operation.status == ArkOperationStatus.succeeded &&
        (_transitionId == null || operation.id == _transitionId);
    final confirmed = _confirmed;
    final amount = confirmed != null && confirmed.account == account
        ? confirmed.net
        : null;
    final fiat = amount == null
        ? null
        : arkFiatText(context, amount, widget.displayData?.price);
    final view = widget.onViewDetails;
    return BullSuccessScreen(
      title: l10n.send,
      headline: completed
          ? l10n.paymentSent
          : operation.status == ArkOperationStatus.succeeded
          ? l10n.pending
          : operation.status.toTranslated(context),
      icon: completed
          ? null
          : ExcludeSemantics(
              child: BullIcon(
                BullIcons.schedule,
                size: 32,
                color: context.bull.textMuted,
              ),
            ),
      amountLine: amount == null
          ? null
          : fiat == null
          ? formatArkSats(context, amount)
          : '${formatArkSats(context, amount)} · ~$fiat',
      message: completed
          ? null
          : BullText(
              l10n.paymentPendingNote,
              role: BullTextRole.body,
              color: context.bull.textMuted,
              textAlign: TextAlign.center,
              maxLines: 4,
            ),
      onClose: _home,
      actions: [
        if ((view, operation.nativeReference)
            case (final open?, final reference?)
            when reference.trim().isNotEmpty &&
                (_transitionId == null || operation.id == _transitionId))
          BullButton.secondary(
            label: l10n.viewDetails,
            onPressed: () => open(reference),
          ),
      ],
    );
  }

  // Null until the preference is read: confirming waits for it, so a payment
  // can never take the animation path against a stored "off".
  bool? _animations;

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
    _destination = widget.initialDestination;
    _amountStep = _destination.trim().isNotEmpty;
    _listen();
  }

  @override
  void didUpdateWidget(ArkPaymentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.cubit, widget.cubit)) {
      unawaited(_subscription.cancel());
      _destination = widget.initialDestination;
      _amount = '';
      _amountStep = _destination.trim().isNotEmpty;
      _scanIntent = null;
      _scanFailed = false;
      _confirmed = null;
      _showTransition = false;
      _transitionId = null;
      ++_phase;
      _listen();
    } else if (oldWidget.onScan != widget.onScan) {
      _scanIntent = null;
      ++_phase;
    }
  }

  @override
  void dispose() {
    _scanIntent = null;
    _scanInFlight = null;
    unawaited(_subscription.cancel());
    super.dispose();
  }

  void _edit(
    ArkPaymentCubit owner,
    ArkAccountId account,
    int phase,
    String value, {
    required bool destination,
  }) {
    if (!_owns(owner, account) ||
        phase != _phase ||
        destination == _amountStep) {
      return;
    }
    final current = owner.state;
    if (current is! ArkPaymentEditing && current is! ArkPaymentQuoting) return;
    _scanIntent = null;
    owner.edit();
    if (!_owns(owner, account) || owner.state is! ArkPaymentEditing) return;
    setState(() {
      _scanFailed = false;
      if (destination) {
        _destination = value;
      } else {
        _amount = value;
      }
    });
  }

  void _advance(
    ArkPaymentCubit owner,
    ArkAccountId account,
    ArkPaymentEditing state,
    int phase,
  ) {
    if (!_current(owner, account, state) ||
        phase != _phase ||
        _amountStep ||
        _destination.trim().isEmpty) {
      return;
    }
    _scanIntent = null;
    owner.edit();
    setState(() {
      _amountStep = true;
      ++_phase;
    });
  }

  void _review(
    ArkPaymentCubit owner,
    ArkAccountId account,
    ArkPaymentEditing state,
    int phase,
  ) {
    if (!_current(owner, account, state) ||
        phase != _phase ||
        !_amountStep ||
        _amount.isEmpty) {
      return;
    }
    unawaited(owner.review(destination: _destination, amount: _amount));
  }

  void _confirm(
    ArkPaymentCubit owner,
    ArkAccountId account,
    ArkPaymentReview state, {
    bool cancel = false,
  }) {
    if (!_current(owner, account, state) ||
        state.quote.account != account ||
        state.quote.kind != ArkOperationKind.payment) {
      return;
    }
    if (!cancel && _animations == null) return;
    if (cancel) {
      owner.edit();
    } else {
      _confirmed = state.quote;
      final submission = owner.confirm();
      if (owner.state case ArkPaymentSubmitting(:final operationId)) {
        setState(() {
          _showTransition = _animations == true;
          _transitionId = operationId;
        });
      }
      unawaited(submission);
    }
  }

  void _back(
    ArkPaymentCubit owner,
    ArkAccountId account,
    ArkPaymentState state,
    int phase,
  ) {
    if (!_current(owner, account, state) || phase != _phase) return;
    _scanIntent = null;
    if (state is ArkPaymentReview &&
        state.quote.account == account &&
        state.quote.kind == ArkOperationKind.payment) {
      _confirm(owner, account, state, cancel: true);
      setState(() {
        _amountStep = true;
        ++_phase;
      });
    } else if (state is ArkPaymentEditing && _amountStep) {
      owner.edit();
      setState(() {
        _amountStep = false;
        ++_phase;
      });
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _scan(
    ArkPaymentCubit owner,
    ArkAccountId account,
    ArkPaymentEditing state,
    int phase,
    Future<String?> Function() scanner,
  ) async {
    if (!_current(owner, account, state) ||
        phase != _phase ||
        _amountStep ||
        _scanInFlight != null ||
        scanner != widget.onScan) {
      return;
    }
    final token = Object();
    setState(() {
      _scanInFlight = token;
      _scanIntent = token;
      _scanFailed = false;
    });
    try {
      final value = await scanner();
      if (value == null ||
          !_owns(owner, account) ||
          phase != _phase ||
          _amountStep ||
          owner.state is! ArkPaymentEditing ||
          !identical(_scanIntent, token) ||
          scanner != widget.onScan) {
        return;
      }
      _edit(owner, account, phase, value, destination: true);
    } on Exception {
      if (_owns(owner, account) &&
          phase == _phase &&
          !_amountStep &&
          identical(_scanIntent, token) &&
          scanner == widget.onScan) {
        setState(() => _scanFailed = true);
      }
    } finally {
      if (mounted && identical(_scanInFlight, token)) {
        setState(() {
          _scanInFlight = null;
          if (identical(_scanIntent, token)) _scanIntent = null;
        });
      }
    }
  }

  Sats? get _preview {
    if (!RegExp(r'^[0-9]+$').hasMatch(_amount)) return null;
    final value = BigInt.tryParse(_amount);
    return value == null || value.isNegative ? null : Sats(value);
  }

  Widget _action(
    BuildContext context,
    String label,
    VoidCallback callback, {
    bool disabled = false,
  }) => BullButton.primary(label: label, onPressed: disabled ? null : callback);

  // Same insets as the app's send flow.
  Widget _footer(BuildContext context, Widget child) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        BullSpacing.md,
        BullSpacing.xs,
        BullSpacing.md,
        BullSpacing.md,
      ),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.loc;
    final owner = widget.cubit;
    final account = owner.account;
    final state = owner.state;
    final phase = _phase;
    final transitionId = _transitionId;
    if (_showTransition && transitionId != null) {
      final operation = switch (state) {
        ArkPaymentSubmitted(:final operation)
            when operation.id == transitionId &&
                operation.kind == ArkOperationKind.payment =>
          operation,
        _ => null,
      };
      final transitionPhase = switch (operation?.status) {
        ArkOperationStatus.succeeded => BullPaymentPhase.success,
        ArkOperationStatus.failed ||
        ArkOperationStatus.conflicted => BullPaymentPhase.failed,
        _ => BullPaymentPhase.sending,
      };
      void dismiss() {
        if (_owns(owner, account) && _transitionId == transitionId) {
          setState(() => _showTransition = false);
        }
      }

      final progress = arkPaymentProgress(
        operation?.status,
        steps: [l10n.operationPending, l10n.operationCompleted],
      );
      return BullPaymentTransition(
        network: BullPaymentNetwork.ark,
        phase: transitionPhase,
        statusTag: operation?.status.toTranslated(context),
        progress: progress,
        status: operation?.status.toTranslated(context) ?? l10n.loading,
        skipLabel: BullUiLocalizations.of(context).paymentViewStatus,
        onSkip: dismiss,
        onBackdropTap: dismiss,
        onDone: dismiss,
      );
    }
    final editing = state is ArkPaymentEditing || state is ArkPaymentQuoting;
    final review =
        state is ArkPaymentReview &&
            state.quote.account == account &&
            state.quote.kind == ArkOperationKind.payment
        ? state
        : null;
    if (state case ArkPaymentSubmitted(:final operation)
        when operation.kind == ArkOperationKind.payment &&
            _started(operation.status)) {
      return _success(account, operation);
    }
    final localBack =
        (state is ArkPaymentEditing && _amountStep) || review != null;
    return PopScope<Object?>(
      canPop: !localBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back(owner, account, state, phase);
      },
      child: BullScaffold(
        backgroundColor: context.bull.background,
        bottomNavigationBar: review != null
            ? _footer(
                context,
                _action(
                  context,
                  l10n.confirm,
                  () => _confirm(owner, account, review),
                  disabled: _animations == null,
                ),
              )
            : editing && _amountStep
            ? _footer(
                context,
                _action(context, l10n.continueAction, () {
                  if (state is ArkPaymentEditing) {
                    _review(owner, account, state, phase);
                  }
                }, disabled: state is ArkPaymentQuoting || _amount.isEmpty),
              )
            : null,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BullTopBar(
                title: l10n.send,
                onBack: () => _back(owner, account, state, phase),
              ),
              Expanded(
                child: editing
                    ? _amountStep
                          ? _amountForm(context, owner, account, state, phase)
                          : _addressForm(context, owner, account, state, phase)
                    // Sending, or closing to home when unsettled: Bull's
                    // cubes in the middle of the screen.
                    : state is ArkPaymentSubmitting ||
                          state is ArkPaymentSubmitted ||
                          state is ArkPaymentUncertain
                    ? const Center(child: BullLoader.large())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(BullSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (state is ArkPaymentReview && review == null)
                              // The app's error state, retried by editing.
                              BullErrorState(
                                message: l10n.unavailable,
                                retryLabel: l10n.retry,
                                onRetry: owner.edit,
                              ),
                            if (review != null)
                              ..._reviewDetails(context, account, review),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addressForm(
    BuildContext context,
    ArkPaymentCubit owner,
    ArkAccountId account,
    ArkPaymentState state,
    int phase,
  ) {
    final l10n = context.loc;
    final scanner = widget.onScan;
    final editing = state is ArkPaymentEditing ? state : null;
    void set(String value) {
      final current = owner.state;
      if (current is ArkPaymentEditing) {
        _edit(owner, account, phase, value, destination: true);
      }
    }

    // The app's send address step: one destination field with paste, scan
    // and clear, and Continue pinned below.
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              BullSpacing.md,
              BullSpacing.xl,
              BullSpacing.md,
              BullSpacing.md,
            ),
            child: BullPaymentDestinationInput(
              key: const ValueKey('ark-payment-address'),
              label: l10n.recipientAddress,
              value: _destination,
              hint: l10n.paymentAddressHint,
              enabled: editing != null,
              onChanged: set,
              pasteLabel: l10n.paymentPaste,
              scanLabel: l10n.paymentScan,
              clearLabel: l10n.paymentClear,
              onClear: () => set(''),
              onPaste: () async {
                final text = (await Clipboard.getData('text/plain'))?.text;
                if (mounted && text != null) set(text);
              },
              onScan: () {
                // A callback kept from an earlier frame never acts for a
                // replaced owner or scanner, or after dispose.
                if (!mounted ||
                    !identical(owner, widget.cubit) ||
                    !identical(scanner, widget.onScan)) {
                  return;
                }
                final current = owner.state;
                if (scanner == null) {
                  setState(() => _scanFailed = true);
                } else if (_scanInFlight == null &&
                    current is ArkPaymentEditing) {
                  unawaited(_scan(owner, account, current, phase, scanner));
                }
              },
              error: editing?.failure?.toTranslated(context),
              helper: _scanFailed ? l10n.cameraUnavailable : null,
            ),
          ),
        ),
        _footer(
          context,
          _action(context, l10n.continueAction, () {
            final current = owner.state;
            if (current is ArkPaymentEditing) {
              _advance(owner, account, current, phase);
            }
          }, disabled: editing == null || _destination.trim().isEmpty),
        ),
      ],
    );
  }

  Widget _amountForm(
    BuildContext context,
    ArkPaymentCubit owner,
    ArkAccountId account,
    ArkPaymentState state,
    int phase,
  ) {
    final l10n = context.loc;
    final preview = _preview;
    final balance = widget.observedSpendable;
    final price = widget.displayData?.account == account
        ? widget.displayData?.price
        : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: BullSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ark pays only from its own balance: the source is stated, not picked.
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: BullSpacing.md),
            color: context.bull.surface,
            alignment: Alignment.centerLeft,
            child: BullText(l10n.title, role: BullTextRole.body),
          ),
          const Gap(BullSpacing.xl),
          BullInputText(
            key: const ValueKey('ark-payment-amount'),
            value: _amount,
            hint: Sats.zero.value.toString(),
            suffixText: l10n.satsUnit,
            digitsOnly: true,
            onlyNumbers: true,
            hideBorder: true,
            style: context.bullType.display,
            disabled: state is ArkPaymentQuoting,
            onChanged: (value) =>
                _edit(owner, account, phase, value, destination: false),
          ),
          if (preview != null) ...[
            const Gap(BullSpacing.xs),
            ArkFiatAmount(amount: preview, price: price, approximate: true),
          ],
          if (state case ArkPaymentEditing(:final failure?)) ...[
            const Gap(BullSpacing.xs),
            // Refused: why, in red, as the app shows it.
            BullText(
              failure.toTranslated(context),
              role: BullTextRole.body,
              fontWeight: FontWeight.w500,
              color: context.bull.error,
              maxLines: 5,
            ),
          ],
          const Gap(BullSpacing.xl),
          Container(height: 1, color: context.bull.outline),
          const Gap(BullSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _labelled(context, l10n.walletLabel, l10n.title),
                    const Gap(BullSpacing.xs),
                    _labelled(
                      context,
                      l10n.balanceLabel,
                      formatArkObservedSats(context, balance),
                    ),
                  ],
                ),
              ),
              BullText(
                l10n.maxAmount.toUpperCase(),
                role: BullTextRole.label,
                color: context.bull.textMuted,
              ),
              const Gap(BullSpacing.sm),
              // Max stays off until a current fee quote can bound it.
              Semantics(
                label: l10n.maxAmount,
                child: const BullSwitch(value: false, onChanged: null),
              ),
            ],
          ),
          const Gap(BullSpacing.xs),
          BullText(
            l10n.maxPaymentUnavailable,
            role: BullTextRole.caption,
            color: context.bull.textMuted,
            textAlign: TextAlign.end,
          ),
        ],
      ),
    );
  }

  Widget _labelled(BuildContext context, String label, String value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      BullText(label, role: BullTextRole.label, color: context.bull.textMuted),
      const Gap(BullSpacing.xxs),
      Flexible(child: BullText(value, role: BullTextRole.label)),
    ],
  );

  List<Widget> _reviewDetails(
    BuildContext context,
    ArkAccountId account,
    ArkPaymentReview state,
  ) {
    final l10n = context.loc;
    final quote = state.quote;
    final price = widget.displayData?.account == account
        ? widget.displayData?.price
        : null;
    String? fiat(Sats amount) => switch (arkFiatText(context, amount, price)) {
      final value? => '~$value',
      null => null,
    };
    // The app's send confirmation: its header, then From, To, Amount and
    // Network fees between thin lines. Ark has no fee priority to choose.
    return [
      ArkReviewHeader(
        title: l10n.confirmSend,
        amount: formatArkSats(context, quote.net),
        icon: widget.confirmIcon,
      ),
      const Gap(BullSpacing.xl),
      ArkReviewFacts(
        children: [
          ArkReviewFact(label: l10n.fromLabel, value: l10n.title),
          switch (quote.destination) {
            final address? => ArkReviewAddress(
              label: l10n.toLabel,
              address: address,
              copiedMessage: l10n.copied,
            ),
            null => ArkReviewFact(label: l10n.toLabel, value: l10n.unknown),
          },
          ArkReviewFact(
            label: l10n.amountLabel,
            value: formatArkSats(context, quote.net),
            detail: fiat(quote.net),
          ),
          ArkReviewFact(
            label: l10n.networkFees,
            value: formatArkSats(context, quote.fee),
          ),
        ],
      ),
    ];
  }
}
