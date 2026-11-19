import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:primitives/primitives.dart' show Sats;
import 'package:flutter/services.dart' show Clipboard;
import 'package:intl/intl.dart';

import '../domain/ark_display_data_port.dart';
import '../presentation/ark_l10n.dart';
import '../presentation/ark_payment_cubit.dart';
import '../presentation/ark_failure_l10n.dart';
import '../presentation/ark_operation_status_l10n.dart';
import 'ark_amount.dart';

/// The caller replaces the owner for a full config or request replacement.
/// Local navigation and scanning never request a quote or submit a payment.
class ArkPaymentScreen extends StatefulWidget {
  final ArkPaymentCubit cubit;
  final String initialDestination;
  final VoidCallback onReconcile;
  final ArkDisplayData? displayData;
  final Sats? observedSpendable;
  final Future<String?> Function()? onScan;

  const ArkPaymentScreen({
    super.key,
    required this.cubit,
    required this.onReconcile,
    this.initialDestination = '',
    this.displayData,
    this.observedSpendable,
    this.onScan,
  });

  @override
  State<ArkPaymentScreen> createState() => _ArkPaymentScreenState();
}

class _ArkPaymentScreenState extends State<ArkPaymentScreen> {
  late String _destination;
  String _amount = '';
  final FocusNode _amountFocus = FocusNode();
  Object? _pasteIntent;
  late bool _amountStep;
  int _phase = 0;
  Object? _scanInFlight;
  Object? _scanIntent;
  bool _scanFailed = false;
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
    _subscription = owner.stream.listen((_) {
      if (_owns(owner, account)) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _amountFocus.addListener(_focusChanged);
    _destination = widget.initialDestination;
    _amountStep = _destination.trim().isNotEmpty;
    _listen();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Covering the page revokes the intent even if it is uncovered before reply.
    if (ModalRoute.of(context)?.isCurrent != true) _pasteIntent = null;
  }

  @override
  void didUpdateWidget(ArkPaymentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.cubit, widget.cubit)) {
      unawaited(_subscription.cancel());
      _destination = widget.initialDestination;
      _amount = '';
      _pasteIntent = null;
      _amountStep = _destination.trim().isNotEmpty;
      _scanIntent = null;
      _scanFailed = false;
      ++_phase;
      _listen();
    } else if (oldWidget.onScan != widget.onScan) {
      _scanIntent = null;
      ++_phase;
    }
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amountFocus.removeListener(_focusChanged);
    _amountFocus.dispose();
    _pasteIntent = null;
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
    if (current is! ArkPaymentEditing && current is! ArkPaymentQuoting) {
      return;
    }
    _scanIntent = null;
    _pasteIntent = null;
    owner.edit();
    if (!_owns(owner, account) || owner.state is! ArkPaymentEditing) {
      return;
    }
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
    _pasteIntent = null;
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
    if (cancel) {
      owner.edit();
    } else {
      unawaited(owner.confirm());
    }
  }

  void _back(
    ArkPaymentCubit owner,
    ArkAccountId account,
    ArkPaymentState state,
    int phase,
  ) {
    if (!_current(owner, account, state) || phase != _phase) {
      return;
    }
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
      _pasteIntent = null;
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

  Future<void> _paste(
    ArkPaymentCubit owner,
    ArkAccountId account,
    ArkPaymentState state,
    int phase,
  ) async {
    if (!_current(owner, account, state) ||
        phase != _phase ||
        _amountStep ||
        state is! ArkPaymentEditing) {
      return;
    }
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;
    final token = Object();
    _pasteIntent = token;
    _scanIntent = null;
    try {
      final value = (await Clipboard.getData('text/plain'))?.text;
      if (!_current(owner, account, state) ||
          phase != _phase ||
          _amountStep ||
          !identical(_pasteIntent, token) ||
          !identical(ModalRoute.of(context), route) ||
          !route.isCurrent ||
          value == null) {
        return;
      }
      _edit(owner, account, phase, value, destination: true);
    } on Exception {
      // An unavailable clipboard leaves the existing manual entry intact.
    }
  }

  String _displayAmount(BuildContext context) {
    if (_amountFocus.hasFocus || !RegExp(r'^[0-9]+$').hasMatch(_amount)) {
      return _amount;
    }
    final separator = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    ).symbols.GROUP_SEP;
    return _amount.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => separator,
    );
  }

  void _reconcile(
    ArkPaymentCubit owner,
    ArkAccountId account,
    ArkPaymentState state,
  ) {
    if (!_current(owner, account, state) ||
        (state is! ArkPaymentSubmitted && state is! ArkPaymentUncertain)) {
      return;
    }
    unawaited(owner.reconcile());
  }

  void _done(
    ArkPaymentCubit owner,
    ArkAccountId account,
    ArkPaymentSubmitted state,
  ) {
    if (!_current(owner, account, state) ||
        state.operation.kind != ArkOperationKind.payment ||
        state.operation.status != ArkOperationStatus.succeeded) {
      return;
    }
    unawaited(Navigator.maybePop(context));
  }

  Sats? get _preview {
    // The empty form displays its zero placeholder equivalent.
    if (_amount.isEmpty) return Sats.zero;
    if (!RegExp(r'^[0-9]+$').hasMatch(_amount)) return null;
    final value = BigInt.tryParse(_amount);
    return value == null || value.isNegative ? null : Sats(value);
  }

  Widget _action(
    BuildContext context,
    String label,
    VoidCallback callback, {
    bool disabled = false,
    bool primary = false,
  }) => BullButton.big(
    label: label,
    height: 56,
    onPressed: callback,
    disabled: disabled,
    bgColor: primary ? context.bull.primary : context.bull.secondary,
    textColor: primary ? context.bull.onPrimary : context.bull.onSecondary,
  );

  Widget _footer(BuildContext context, Widget child) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        BullSpacing.lg,
        BullSpacing.sm,
        BullSpacing.lg,
        BullSpacing.lg,
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
    final editing = state is ArkPaymentEditing || state is ArkPaymentQuoting;
    final review =
        state is ArkPaymentReview &&
            state.quote.account == account &&
            state.quote.kind == ArkOperationKind.payment
        ? state
        : null;
    final succeeded =
        state is ArkPaymentSubmitted &&
            state.operation.kind == ArkOperationKind.payment &&
            state.operation.status == ArkOperationStatus.succeeded
        ? state
        : null;
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
                  primary: true,
                ),
              )
            : succeeded != null
            ? _footer(
                context,
                _action(
                  context,
                  l10n.done,
                  () => _done(owner, account, succeeded),
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
              if (succeeded == null)
                Padding(
                  padding: const EdgeInsets.only(
                    top: BullSpacing.lg,
                    bottom: BullSpacing.sm,
                  ),
                  child: BullTopBar(
                    title: l10n.send,
                    titleWidget: BullText(
                      l10n.send,
                      role: BullTextRole.subtitle,
                    ),
                    onBack: () => _back(owner, account, state, phase),
                  ),
                ),
              Expanded(
                child: succeeded != null
                    ? Center(
                        child: Semantics(
                          key: const ValueKey('ark-payment-success'),
                          liveRegion: true,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: context.bull.success.withValues(
                                    alpha: 0.12,
                                  ),
                                ),
                                child: Center(
                                  child: BullIcon(
                                    BullIcons.check,
                                    size: 34,
                                    color: context.bull.success,
                                  ),
                                ),
                              ),
                              const Gap(BullSpacing.lg),
                              BullText(
                                l10n.paymentSent,
                                role: BullTextRole.headline,
                                fontWeight: FontWeight.w700,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : editing
                    ? _amountStep
                          ? _amountForm(context, owner, account, state, phase)
                          : _addressForm(context, owner, account, state, phase)
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(BullSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (state is ArkPaymentReview && review == null)
                              BullInfoBar(message: l10n.unavailable),
                            if (review != null)
                              ..._reviewDetails(context, account, review),
                            if (state is ArkPaymentSubmitting)
                              BullText(l10n.loading, role: BullTextRole.body),
                            if ((state is ArkPaymentSubmitted &&
                                    succeeded == null) ||
                                state is ArkPaymentUncertain)
                              ..._operationDetails(
                                context,
                                owner,
                                account,
                                state,
                              ),
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
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(BullSpacing.lg),
            child: Column(
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: context.bull.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(
                      context.bullShapes.sheet,
                    ),
                  ),
                  child: ExcludeSemantics(
                    child: BullIcon(
                      BullIcons.qrCode,
                      size: 70,
                      color: context.bull.text,
                    ),
                  ),
                ),
                const Gap(BullSpacing.lg),
                BullText(
                  l10n.paymentScanHint,
                  role: BullTextRole.body,
                  textAlign: TextAlign.center,
                ),
                const Gap(BullSpacing.lg),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 196),
                  child: BullButton.big(
                    label: l10n.openCamera,
                    compact: true,
                    height: 52,
                    textStyle: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    disabled:
                        scanner == null ||
                        _scanInFlight != null ||
                        state is! ArkPaymentEditing,
                    onPressed: () {
                      if (scanner != null && state is ArkPaymentEditing) {
                        unawaited(_scan(owner, account, state, phase, scanner));
                      }
                    },
                    bgColor: context.bull.secondary,
                    textColor: context.bull.onSecondary,
                  ),
                ),
                if (_scanFailed) ...[
                  const Gap(BullSpacing.md),
                  BullInfoBar(message: l10n.cameraUnavailable),
                ],
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: BullSpacing.md,
            vertical: BullSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: context.bull.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(context.bullShapes.sheet),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BullText(l10n.recipientAddress, role: BullTextRole.body),
              const Gap(BullSpacing.sm),
              BullInputText(
                key: const ValueKey('ark-payment-address'),
                value: _destination,
                hint: l10n.paymentAddressHint,
                rightIcon: Semantics(
                  label: l10n.pasteAddress,
                  child: const BullIcon(BullIcons.contentPaste),
                ),
                onRightTap: () =>
                    unawaited(_paste(owner, account, state, phase)),
                onChanged: (value) =>
                    _edit(owner, account, phase, value, destination: true),
              ),
              if (state case ArkPaymentEditing(:final failure?))
                BullInfoBar(
                  message: failure.toTranslated(context),
                  tone: BullInfoTone.warning,
                ),
              const Gap(BullSpacing.sm),
              _action(
                context,
                l10n.continueAction,
                () {
                  if (state is ArkPaymentEditing) {
                    _advance(owner, account, state, phase);
                  }
                },
                disabled:
                    state is! ArkPaymentEditing || _destination.trim().isEmpty,
              ),
            ],
          ),
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
          Semantics(
            key: const ValueKey('ark-payment-pay-from'),
            label: l10n.payFrom,
            button: true,
            enabled: state is ArkPaymentEditing,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: state is ArkPaymentEditing
                  ? () => _payFrom(owner, account, state, phase)
                  : null,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: BullSpacing.md),
                color: context.bull.surface,
                child: Row(
                  children: [
                    Expanded(
                      child: BullText(l10n.title, role: BullTextRole.body),
                    ),
                    const BullIcon(BullIcons.expandMore),
                  ],
                ),
              ),
            ),
          ),
          const Gap(BullSpacing.xxl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: IntrinsicWidth(
                  child: BullInputText(
                    key: const ValueKey('ark-payment-amount'),
                    value: _displayAmount(context),
                    focusNode: _amountFocus,
                    hint: '0',
                    digitsOnly: true,
                    onlyNumbers: true,
                    hideBorder: true,
                    filled: false,
                    textAlign: TextAlign.center,
                    contentPadding: EdgeInsets.zero,
                    style: context.bullType.display,
                    disabled: state is ArkPaymentQuoting,
                    onChanged: (value) =>
                        _edit(owner, account, phase, value, destination: false),
                  ),
                ),
              ),
              const Gap(BullSpacing.xs),
              BullText(
                key: const ValueKey('ark-payment-amount-unit'),
                l10n.satsUnit,
                style: context.bullType.display,
              ),
            ],
          ),
          const Gap(BullSpacing.sm),
          if (preview != null) ArkFiatAmount(amount: preview, price: price),
          if (state case ArkPaymentEditing(:final failure?))
            BullInfoBar(
              message: failure.toTranslated(context),
              tone: BullInfoTone.warning,
            ),
          const Gap(BullSpacing.lg),
          Semantics(
            enabled: false,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: context.bull.outline),
                borderRadius: BorderRadius.circular(context.bullShapes.input),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: BullInputText(
                      value: '',
                      hint: l10n.noteOptional,
                      disabled: true,
                      hideBorder: true,
                      filled: false,
                      onChanged: (_) {},
                    ),
                  ),
                  const ExcludeSemantics(child: BullIcon(BullIcons.edit)),
                  const Gap(BullSpacing.md),
                ],
              ),
            ),
          ),
          BullText(
            l10n.paymentNoteUnavailable,
            role: BullTextRole.caption,
            color: context.bull.textMuted,
          ),
          const Gap(BullSpacing.lg),
          Container(height: 1, color: context.bull.outline),
          const Gap(BullSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BullText(
                      '${l10n.walletLabel} ${l10n.title}',
                      role: BullTextRole.label,
                    ),
                    const Gap(BullSpacing.xs),
                    BullText(
                      '${l10n.balanceLabel} ${formatArkObservedSats(context, balance)}',
                      role: BullTextRole.label,
                      color: context.bull.textMuted,
                    ),
                  ],
                ),
              ),
              BullButton.small(
                label: l10n.maxAmount.toUpperCase(),
                disabled:
                    state is! ArkPaymentEditing ||
                    balance == null ||
                    balance.value <= BigInt.zero,
                compact: true,
                height: 48,
                width: 80,
                textStyle: context.bullType.label,
                onPressed: () {
                  if (!_current(owner, account, state) ||
                      phase != _phase ||
                      !_amountStep ||
                      state is! ArkPaymentEditing ||
                      balance == null ||
                      balance.value <= BigInt.zero ||
                      widget.observedSpendable != balance) {
                    return;
                  }
                  _edit(
                    owner,
                    account,
                    phase,
                    balance.value.toString(),
                    destination: false,
                  );
                },
                bgColor: context.bull.secondary,
                textColor: context.bull.onSecondary,
              ),
            ],
          ),
          const Gap(BullSpacing.xs),
          BullText(
            l10n.maxBalanceInputHint,
            role: BullTextRole.caption,
            color: context.bull.textMuted,
          ),
        ],
      ),
    );
  }

  Future<void> _payFrom(
    ArkPaymentCubit owner,
    ArkAccountId account,
    ArkPaymentState state,
    int phase,
  ) async {
    if (!_current(owner, account, state) ||
        phase != _phase ||
        !_amountStep ||
        state is! ArkPaymentEditing ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    await BullBottomSheet.show<void>(
      context: context,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(BullSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: BullText(
                  context.loc.payFrom,
                  role: BullTextRole.subtitle,
                ),
              ),
              const Gap(BullSpacing.md),
              BullText(context.loc.title, role: BullTextRole.body),
              BullText(
                formatArkObservedSats(context, widget.observedSpendable),
                role: BullTextRole.label,
              ),
            ],
          ),
        ),
      ),
    );
  }

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
    return [
      Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.bull.surfaceContainerHighest,
          ),
          child: BullIcon(
            BullIcons.chevronRight,
            size: 28,
            color: context.bull.text,
          ),
        ),
      ),
      const Gap(BullSpacing.md),
      BullText(
        l10n.confirmSend,
        role: BullTextRole.body,
        textAlign: TextAlign.center,
      ),
      const Gap(BullSpacing.sm),
      BullText(
        formatArkSats(context, quote.net),
        role: BullTextRole.headline,
        fontWeight: FontWeight.w700,
        textAlign: TextAlign.center,
      ),
      const Gap(BullSpacing.lg),
      BullDetailsTable(
        flat: true,
        items: [
          BullDetailsTableItem(label: l10n.fromLabel, displayValue: l10n.title),
          BullDetailsTableItem(
            label: l10n.toLabel,
            displayValue: quote.destination ?? l10n.unknown,
            copyValue: quote.destination,
            copiedMessage: l10n.copied,
            displayWidget: BullText(
              quote.destination ?? l10n.unknown,
              role: BullTextRole.body,
            ),
          ),
          BullDetailsTableItem(
            label: l10n.amountLabel,
            displayValue: formatArkSats(context, quote.net),
            displayWidget: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                BullText(
                  formatArkSats(context, quote.net),
                  role: BullTextRole.body,
                ),
                ArkFiatAmount(amount: quote.net, price: price),
              ],
            ),
          ),
          BullDetailsTableItem(
            label: l10n.networkFees,
            displayValue: formatArkSats(context, quote.fee),
          ),
          BullDetailsTableItem(
            label: l10n.totalLabel,
            displayValue: formatArkSats(context, quote.amount),
          ),
        ],
      ),
    ];
  }

  List<Widget> _operationDetails(
    BuildContext context,
    ArkPaymentCubit owner,
    ArkAccountId account,
    ArkPaymentState state,
  ) {
    final l10n = context.loc;
    return [
      if (state is ArkPaymentUncertain)
        BullInfoBar(message: l10n.uncertain, tone: BullInfoTone.warning),
      if (state is ArkPaymentSubmitted &&
          state.operation.kind != ArkOperationKind.payment)
        BullInfoBar(message: l10n.unavailable),
      BullDetailsTable(
        items: [
          BullDetailsTableItem(
            label: l10n.id,
            displayValue: switch (state) {
              ArkPaymentSubmitted(:final operation) => operation.id,
              ArkPaymentUncertain(:final operationId) => operationId,
              _ => l10n.unknown,
            },
          ),
          if (state case ArkPaymentSubmitted(:final operation))
            BullDetailsTableItem(
              label: l10n.state,
              displayValue: operation.status.toTranslated(context),
            ),
        ],
      ),
      const Gap(BullSpacing.md),
      BullButton.big(
        label: l10n.refresh,
        disabled: !owner.canReconcile,
        onPressed: () => _reconcile(owner, account, state),
        bgColor: context.bull.secondary,
        textColor: context.bull.onSecondary,
      ),
    ];
  }
}
