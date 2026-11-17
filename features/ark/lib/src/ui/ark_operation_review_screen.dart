import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';

import '../presentation/ark_l10n.dart';
import '../presentation/ark_operation_cubit.dart';
import '../presentation/ark_failure_l10n.dart';
import '../presentation/ark_operation_status_l10n.dart';

/// The parent's explicit Review action starts load before mounting this page.
/// Replace the injected owner on every full configuration/request change.
class ArkOperationReviewScreen extends StatefulWidget {
  final ArkOperationCubit cubit;
  final VoidCallback onReconcile;
  const ArkOperationReviewScreen({
    super.key,
    required this.cubit,
    required this.onReconcile,
  });
  @override
  State<ArkOperationReviewScreen> createState() =>
      _ArkOperationReviewScreenState();
}

class _ArkOperationReviewScreenState extends State<ArkOperationReviewScreen> {
  late StreamSubscription<ArkOperationState> _subscription;
  bool _owns(ArkOperationCubit owner, ArkAccountId account) =>
      mounted &&
      !owner.isClosed &&
      identical(owner, widget.cubit) &&
      account == widget.cubit.account;
  bool _current(
    ArkOperationCubit owner,
    ArkAccountId account,
    ArkOperationState rendered,
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
    _listen();
  }

  @override
  void didUpdateWidget(ArkOperationReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.cubit, widget.cubit)) {
      unawaited(_subscription.cancel());
      _listen();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  void _confirm(
    ArkOperationCubit owner,
    ArkAccountId account,
    ArkOperationReview rendered,
  ) {
    if (!_current(owner, account, rendered)) return;
    final current = widget.cubit.state;
    if (current is! ArkOperationReview ||
        !identical(current.quote, rendered.quote) ||
        current.quote.account != account) {
      return;
    }
    unawaited(widget.cubit.confirm());
  }

  void _retry(
    ArkOperationCubit owner,
    ArkAccountId account,
    ArkOperationFailed rendered,
  ) {
    if (_current(owner, account, rendered)) unawaited(widget.cubit.load());
  }

  void _reconcile(
    ArkOperationCubit owner,
    ArkAccountId account,
    ArkOperationState rendered,
  ) {
    if (!_current(owner, account, rendered) ||
        (rendered is! ArkOperationSubmitted &&
            rendered is! ArkOperationUncertain)) {
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
    return BullScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BullSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BullTopBar(
                title: l10n.review,
                onBack: () => Navigator.pop(context),
              ),
              if (state is ArkOperationLoading ||
                  state is ArkOperationSubmitting)
                BullText(l10n.loading, style: null),
              if (state case final ArkOperationFailed failed) ...[
                BullInfoBar(
                  message: failed.failure.toTranslated(context),
                  tone: BullInfoTone.warning,
                ),
                _button(
                  context,
                  l10n.review,
                  () => _retry(owner, account, failed),
                ),
              ],
              if (state case final ArkOperationReview reviewed) ...[
                if (reviewed.quote.account != account)
                  BullInfoBar(message: l10n.unavailable),
                if (reviewed.quote.account == account) ...[
                  BullDetailsTable(
                    items: [
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
                      if (reviewed.quote.destination case final destination?)
                        BullDetailsTableItem(
                          label: l10n.destination,
                          displayValue: destination,
                        ),
                      for (final id in reviewed.quote.selectedIds)
                        BullDetailsTableItem(label: l10n.id, displayValue: id),
                    ],
                  ),
                  _button(
                    context,
                    l10n.confirm,
                    () => _confirm(owner, account, reviewed),
                    primary: true,
                  ),
                ],
              ],
              if (state case ArkOperationSubmitted(:final operation))
                BullDetailsTable(
                  items: [
                    BullDetailsTableItem(
                      label: l10n.id,
                      displayValue: operation.id,
                    ),
                    BullDetailsTableItem(
                      label: l10n.state,
                      displayValue: operation.status.toTranslated(context),
                    ),
                  ],
                ),
              if (state case ArkOperationUncertain(:final operationId)) ...[
                BullInfoBar(
                  message: l10n.uncertain,
                  tone: BullInfoTone.warning,
                ),
                BullDetailsTable(
                  items: [
                    BullDetailsTableItem(
                      label: l10n.id,
                      displayValue: operationId,
                    ),
                  ],
                ),
              ],
              if (state is ArkOperationSubmitted ||
                  state is ArkOperationUncertain)
                _button(
                  context,
                  l10n.refresh,
                  () => _reconcile(owner, account, state),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _button(
    BuildContext context,
    String label,
    VoidCallback action, {
    bool primary = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: BullSpacing.md),
    child: BullButton.big(
      label: label,
      onPressed: action,
      bgColor: primary ? context.bull.primary : context.bull.surface,
      textColor: primary ? context.bull.onPrimary : context.bull.text,
    ),
  );
}
