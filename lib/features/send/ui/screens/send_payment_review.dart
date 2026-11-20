import 'package:bull_ui/bull_ui.dart';

/// Read-only payment facts. Amount and destination widgets may expose viewing,
/// copying and shared denomination changes; only the note can edit intent.
class SendPaymentReview extends StatelessWidget {
  const SendPaymentReview({
    super.key,
    required this.title,
    required this.stepLabels,
    required this.stepSemanticLabel,
    required this.youSendLabel,
    required this.amount,
    required this.equivalent,
    required this.recipients,
    required this.fromLabel,
    required this.source,
    required this.noteLabel,
    required this.note,
    required this.feeLabel,
    required this.fee,
    required this.feeDetail,
    required this.totalLabel,
    required this.total,
    required this.confirmLabel,
    required this.onBack,
    required this.onNote,
    required this.onConfirm,
    this.enteredDetail,
    this.changeLabel,
    this.change,
  }) : assert((change == null) == (changeLabel == null));

  final String title;
  final List<String> stepLabels;
  final String Function(int, String) stepSemanticLabel;
  final String youSendLabel;
  final Widget amount;
  final String equivalent;
  final String? enteredDetail;

  /// Ordered destination blocks, grouped exactly as on the recipient page.
  final List<Widget> recipients;
  final String fromLabel;
  final Widget source;
  final String? changeLabel;
  final Widget? change;
  final String noteLabel;
  final String note;
  final String feeLabel;
  final Widget fee;
  final String feeDetail;
  final String totalLabel;
  final Widget total;
  final String confirmLabel;
  final VoidCallback onBack;
  final VoidCallback onNote;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) => BullScaffold(
    body: SafeArea(
      child: Column(
        children: [
          BullTopBar(title: title, onBack: onBack),
          BullStepBar(
            labels: stepLabels,
            currentStep: 2,
            semanticLabel: stepSemanticLabel,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(BullSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(youSendLabel, style: context.bullType.body),
                  const Gap(BullSpacing.xs),
                  amount,
                  Text(
                    equivalent,
                    style: context.bullType.label.copyWith(
                      color: context.bull.textMuted,
                    ),
                  ),
                  if (enteredDetail case final entered?) ...[
                    const Gap(BullSpacing.xs),
                    Text(
                      entered,
                      style: context.bullType.label.copyWith(
                        color: context.bull.textMuted,
                      ),
                    ),
                  ],
                  const Gap(BullSpacing.lg),
                  for (final recipient in recipients) ...[
                    recipient,
                    const Gap(BullSpacing.md),
                  ],
                  _ReviewFact(label: fromLabel, child: source),
                  if ((changeLabel, change) case (
                    final label?,
                    final destination?,
                  ))
                    _ReviewFact(label: label, child: destination),
                  BullInlineTextButton(
                    onPressed: onNote,
                    child: _ReviewFact(
                      label: noteLabel,
                      child: Text(note, style: context.bullType.body),
                    ),
                  ),
                  _ReviewFact(
                    label: feeLabel,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        fee,
                        Text(
                          feeDetail,
                          style: context.bullType.label.copyWith(
                            color: context.bull.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ReviewFact(label: totalLabel, child: total),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(BullSpacing.md),
            child: SizedBox(
              width: double.infinity,
              child: BullButton.primary(
                label: confirmLabel,
                onPressed: onConfirm,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReviewFact extends StatelessWidget {
  const _ReviewFact({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: BullSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: context.bullType.label.copyWith(color: context.bull.textMuted),
        ),
        const Gap(BullSpacing.xs),
        child,
      ],
    ),
  );
}
