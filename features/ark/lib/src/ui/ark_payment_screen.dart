import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';

import '../presentation/ark_l10n.dart';
import '../presentation/ark_payment_cubit.dart';
import '../presentation/ark_failure_l10n.dart';
import '../presentation/ark_operation_status_l10n.dart';

/// Replace the injected owner for every full config/request/context change.
/// Mounting, initial destination and edits never request a quote.
class ArkPaymentScreen extends StatefulWidget {
  final ArkPaymentCubit cubit;
  final String initialDestination;
  final VoidCallback onReconcile;
  const ArkPaymentScreen({
    super.key,
    required this.cubit,
    this.initialDestination = '',
    required this.onReconcile,
  });
  @override
  State<ArkPaymentScreen> createState() => _ArkPaymentScreenState();
}

class _ArkPaymentScreenState extends State<ArkPaymentScreen> {
  late String _destination;
  String _amount = '';
  late StreamSubscription<ArkPaymentState> _subscription;
  bool _owns(ArkPaymentCubit owner, ArkAccountId account) =>
      mounted &&
      !owner.isClosed &&
      identical(owner, widget.cubit) &&
      account == widget.cubit.account;
  bool _current(
    ArkPaymentCubit owner,
    ArkAccountId account,
    ArkPaymentState rendered,
  ) => _owns(owner, account) && identical(rendered, widget.cubit.state);
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
    _listen();
  }

  @override
  void didUpdateWidget(ArkPaymentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.cubit, widget.cubit)) {
      unawaited(_subscription.cancel());
      _destination = widget.initialDestination;
      _amount = '';
      _listen();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  void _edit(
    ArkPaymentCubit owner,
    ArkAccountId account,
    String value, {
    required bool destination,
  }) {
    if (!_owns(owner, account)) return;
    final current = owner.state;
    if (current is! ArkPaymentEditing && current is! ArkPaymentQuoting) return;
    owner.edit(); // Invalidate any pending quote before publishing local text.
    if (!_owns(owner, account) || owner.state is! ArkPaymentEditing) return;
    setState(() {
      if (destination) {
        _destination = value;
      } else {
        _amount = value;
      }
    });
  }

  void _review(
    ArkPaymentCubit owner,
    ArkAccountId account,
    ArkPaymentEditing rendered,
  ) {
    if (!_current(owner, account, rendered)) return;
    final destination = _destination;
    final amount = _amount;
    unawaited(owner.review(destination: destination, amount: amount));
  }

  void _confirm(
    ArkPaymentCubit owner,
    ArkAccountId account,
    ArkPaymentReview rendered, {
    bool cancel = false,
  }) {
    if (!_current(owner, account, rendered)) return;
    final current = owner.state;
    if (current is! ArkPaymentReview ||
        !identical(current.quote, rendered.quote) ||
        current.quote.account != account) {
      return;
    }
    if (cancel) {
      owner.edit();
    } else {
      unawaited(owner.confirm());
    }
  }

  void _reconcile(
    ArkPaymentCubit owner,
    ArkAccountId account,
    ArkPaymentState rendered,
  ) {
    if (!_current(owner, account, rendered) ||
        (rendered is! ArkPaymentSubmitted &&
            rendered is! ArkPaymentUncertain)) {
      return;
    }
    widget.onReconcile();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final owner = widget.cubit;
    final account = owner.account;
    final state = owner.state;
    final editing = state is ArkPaymentEditing || state is ArkPaymentQuoting;
    return BullScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BullSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BullTopBar(
                title: l10n.send,
                onBack: () => Navigator.pop(context),
              ),
              if (editing) ...[
                BullInputText(
                  value: _destination,
                  hint: l10n.destination,
                  disabled: state is ArkPaymentQuoting,
                  onChanged: (value) {
                    _edit(owner, account, value, destination: true);
                  },
                ),
                const Gap(BullSpacing.md),
                BullInputText(
                  value: _amount,
                  hint: l10n.amount,
                  digitsOnly: true,
                  onlyNumbers: true,
                  disabled: state is ArkPaymentQuoting,
                  onChanged: (value) {
                    _edit(owner, account, value, destination: false);
                  },
                ),
                const Gap(BullSpacing.md),
                if (state case ArkPaymentEditing(:final failure?))
                  BullInfoBar(
                    message: failure.toTranslated(context),
                    tone: BullInfoTone.warning,
                  ),
                BullButton.big(
                  label: l10n.review,
                  onPressed: () {
                    if (state is ArkPaymentEditing) {
                      _review(owner, account, state);
                    }
                  },
                  disabled: state is ArkPaymentQuoting,
                  bgColor: context.bull.primary,
                  textColor: context.bull.onPrimary,
                ),
              ],
              if (state case final ArkPaymentReview reviewed) ...[
                if (reviewed.quote.account != account)
                  BullInfoBar(message: l10n.unavailable),
                if (reviewed.quote.account == account) ...[
                  BullDetailsTable(
                    items: [
                      BullDetailsTableItem(
                        label: l10n.destination,
                        displayValue:
                            reviewed.quote.destination ?? l10n.unknown,
                      ),
                      BullDetailsTableItem(
                        label: l10n.amount,
                        displayValue: reviewed.quote.amount.value.toString(),
                      ),
                      BullDetailsTableItem(
                        label: l10n.feeInSats,
                        displayValue: reviewed.quote.fee.value.toString(),
                      ),
                      BullDetailsTableItem(
                        label: l10n.netInSats,
                        displayValue: reviewed.quote.net.value.toString(),
                      ),
                    ],
                  ),
                  const Gap(BullSpacing.md),
                  BullButton.big(
                    label: l10n.confirm,
                    onPressed: () => _confirm(owner, account, reviewed),
                    bgColor: context.bull.primary,
                    textColor: context.bull.onPrimary,
                  ),
                  const Gap(BullSpacing.xs),
                  BullButton.big(
                    label: l10n.cancel,
                    onPressed: () =>
                        _confirm(owner, account, reviewed, cancel: true),
                    bgColor: context.bull.surface,
                    textColor: context.bull.text,
                  ),
                ],
              ],
              if (state is ArkPaymentSubmitting)
                BullText(l10n.loading, style: null),
              if (state is ArkPaymentSubmitted ||
                  state is ArkPaymentUncertain) ...[
                if (state is ArkPaymentUncertain)
                  BullInfoBar(
                    message: l10n.uncertain,
                    tone: BullInfoTone.warning,
                  ),
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
                BullButton.big(
                  label: l10n.refresh,
                  onPressed: () => _reconcile(owner, account, state),
                  bgColor: context.bull.surface,
                  textColor: context.bull.text,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
