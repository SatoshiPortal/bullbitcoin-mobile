import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:primitives/primitives.dart' show Sats;

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
    if (!RegExp(r'^[0-9]+$').hasMatch(_amount)) return null;
    final value = BigInt.tryParse(_amount);
    return value == null || value.isNegative ? null : Sats(value);
  }

  Widget _action(
    BuildContext context,
    String label,
    VoidCallback callback, {
    bool disabled = false,
  }) => BullButton.big(
    label: label,
    height: 56,
    onPressed: callback,
    disabled: disabled,
    bgColor: context.bull.secondaryFixed,
    textColor: context.bull.onSecondaryFixed,
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
              Padding(
                padding: const EdgeInsets.only(
                  top: BullSpacing.lg,
                  bottom: BullSpacing.sm,
                ),
                child: BullTopBar(
                  title: review != null ? l10n.confirmSend : l10n.send,
                  titleWidget: BullText(
                    review != null ? l10n.confirmSend : l10n.send,
                    role: BullTextRole.subtitle,
                  ),
                  onBack: () => _back(owner, account, state, phase),
                ),
              ),
              Expanded(
                child: editing
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
                            if (succeeded != null) ...[
                              Center(
                                child: BullIcon(
                                  BullIcons.checkCircle,
                                  size: 72,
                                  color: context.bull.success,
                                ),
                              ),
                              const Gap(BullSpacing.lg),
                              BullText(
                                l10n.paymentSent,
                                role: BullTextRole.headline,
                                textAlign: TextAlign.center,
                              ),
                              const Gap(BullSpacing.lg),
                            ],
                            if (state is ArkPaymentSubmitted ||
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
                      BullIcons.qrCodeScanner,
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
                BullButton.big(
                  label: l10n.openCamera,
                  compact: true,
                  outlined: true,
                  disabled:
                      scanner == null ||
                      _scanInFlight != null ||
                      state is! ArkPaymentEditing,
                  onPressed: () {
                    if (scanner != null && state is ArkPaymentEditing) {
                      unawaited(_scan(owner, account, state, phase, scanner));
                    }
                  },
                  bgColor: context.bull.surface,
                  textColor: context.bull.text,
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
          padding: const EdgeInsets.all(BullSpacing.md),
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
                onChanged: (value) =>
                    _edit(owner, account, phase, value, destination: true),
              ),
              if (state case ArkPaymentEditing(:final failure?))
                BullInfoBar(
                  message: failure.toTranslated(context),
                  tone: BullInfoTone.warning,
                ),
              const Gap(BullSpacing.md),
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
      padding: const EdgeInsets.all(BullSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: BullBadge(
              label: l10n.title,
              background: context.bull.surface,
              foreground: context.bull.text,
              radius: context.bullShapes.dot,
              textStyle: context.bullType.label,
              padding: const EdgeInsets.symmetric(
                horizontal: BullSpacing.md,
                vertical: BullSpacing.xs,
              ),
            ),
          ),
          const Gap(BullSpacing.xl),
          BullInputText(
            key: const ValueKey('ark-payment-amount'),
            value: _amount,
            hint: Sats.zero.value.toString(),
            suffixText: l10n.satsUnit,
            digitsOnly: true,
            onlyNumbers: true,
            style: context.bullType.display,
            disabled: state is ArkPaymentQuoting,
            onChanged: (value) =>
                _edit(owner, account, phase, value, destination: false),
          ),
          if (preview != null) ArkFiatAmount(amount: preview, price: price),
          if (state case ArkPaymentEditing(:final failure?))
            BullInfoBar(
              message: failure.toTranslated(context),
              tone: BullInfoTone.warning,
            ),
          const Gap(BullSpacing.xl),
          Row(
            children: [
              Expanded(
                child: BullText(l10n.walletLabel, role: BullTextRole.body),
              ),
              BullText(
                l10n.title,
                role: BullTextRole.body,
                fontWeight: FontWeight.w700,
              ),
            ],
          ),
          const Gap(BullSpacing.sm),
          Row(
            children: [
              Expanded(
                child: BullText(l10n.balanceLabel, role: BullTextRole.label),
              ),
              BullText(
                formatArkObservedSats(context, balance),
                role: BullTextRole.label,
              ),
            ],
          ),
          const Gap(BullSpacing.sm),
          BullButton.small(
            label: l10n.maxAmount.toUpperCase(),
            disabled: true,
            compact: true,
            onPressed: () {},
            bgColor: context.bull.surfaceContainerHighest,
            textColor: context.bull.textMuted,
          ),
          BullText(
            l10n.maxPaymentUnavailable,
            role: BullTextRole.caption,
            color: context.bull.textMuted,
          ),
        ],
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
            BullIcons.arrowUpward,
            size: 28,
            color: context.bull.text,
          ),
        ),
      ),
      const Gap(BullSpacing.lg),
      BullText(
        formatArkSats(context, quote.net),
        role: BullTextRole.headline,
        fontWeight: FontWeight.w700,
        textAlign: TextAlign.center,
      ),
      ArkFiatAmount(amount: quote.net, price: price),
      const Gap(BullSpacing.lg),
      BullDetailsTable(
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          BullDetailsTableItem(
            label: l10n.amountLabel,
            displayValue: formatArkSats(context, quote.net),
          ),
          BullDetailsTableItem(
            label: l10n.networkFees,
            displayValue: formatArkSats(context, quote.fee),
          ),
          if (quote.amount != quote.net)
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
        bgColor: context.bull.surface,
        textColor: context.bull.text,
      ),
    ];
  }
}
