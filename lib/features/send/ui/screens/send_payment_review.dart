import 'package:bull_ui/bull_ui.dart';

/// Payment facts with viewing/copying callbacks; only the note edits intent.
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
    required this.editLabel,
    required this.feeLabel,
    required this.fee,
    required this.feeDetail,
    required this.totalLabel,
    required this.total,
    required this.confirmLabel,
    required this.onBack,
    required this.onNote,
    required this.onConfirm,
    this.totalEquivalent,
    this.enteredDetail,
    this.error,
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
  final Widget? error;
  final List<Widget> recipients;
  final String fromLabel;
  final Widget source;
  final String? changeLabel;
  final Widget? change;
  final String noteLabel;
  final String note;
  final String editLabel;
  final String feeLabel;
  final Widget fee;
  final String feeDetail;
  final String totalLabel;
  final Widget total;
  final String? totalEquivalent;
  final String confirmLabel;
  final VoidCallback onBack;
  final VoidCallback onNote;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) => BullScaffold(
    backgroundColor: context.bull.background,
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
              padding: const EdgeInsets.fromLTRB(
                BullSpacing.md,
                BullSpacing.lg,
                BullSpacing.md,
                BullSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (error case final message?)
                    Semantics(liveRegion: true, child: message),
                  Padding(
                    padding: const EdgeInsets.only(bottom: BullSpacing.lg),
                    child: Column(
                      children: [
                        Text(
                          youSendLabel,
                          style: context.bullType.body.copyWith(
                            color: context.bull.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const Gap(BullSpacing.xxs),
                        amount,
                        const Gap(BullSpacing.xxs),
                        Text(
                          equivalent,
                          textAlign: TextAlign.center,
                          style: context.bullType.label.copyWith(
                            color: context.bull.textMuted,
                          ),
                        ),
                        if (enteredDetail case final entered?) ...[
                          const Gap(BullSpacing.xxs),
                          Text(
                            entered,
                            textAlign: TextAlign.center,
                            style: context.bullType.caption.copyWith(
                              color: context.bull.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: context.bull.border),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final recipient in recipients)
                          _ReviewBorder(child: recipient),
                        _ReviewFact(label: fromLabel, child: source),
                        if ((changeLabel, change) case (
                          final label?,
                          final destination?,
                        ))
                          _ReviewFact(label: label, child: destination),
                        Semantics(
                          button: true,
                          label: noteLabel,
                          value: note,
                          excludeSemantics: true,
                          onTap: onNote,
                          child: GestureDetector(
                            onTap: onNote,
                            child: _ReviewFact(
                              label: noteLabel,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      note,
                                      textAlign: TextAlign.end,
                                      style: context.bullType.body,
                                    ),
                                  ),
                                  const Gap(BullSpacing.xxs),
                                  BullFieldAction(
                                    label: editLabel,
                                    icon: BullIcons.edit,
                                    onPressed: onNote,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        _ReviewFact(
                          label: feeLabel,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              fee,
                              Text(
                                feeDetail,
                                textAlign: TextAlign.end,
                                style: context.bullType.caption.copyWith(
                                  color: context.bull.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _ReviewFact(
                          label: totalLabel,
                          strong: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              total,
                              if (totalEquivalent case final fiat?)
                                Text(
                                  fiat,
                                  textAlign: TextAlign.end,
                                  style: context.bullType.caption.copyWith(
                                    color: context.bull.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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

class _ReviewBorder extends StatelessWidget {
  const _ReviewBorder({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: BullSpacing.sm),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: context.bull.border)),
    ),
    child: child,
  );
}

class _ReviewFact extends StatelessWidget {
  const _ReviewFact({
    required this.label,
    required this.child,
    this.strong = false,
  });
  final String label;
  final Widget child;
  final bool strong;
  @override
  Widget build(BuildContext context) => _ReviewBorder(
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: strong
                ? context.bullType.body.copyWith(fontWeight: FontWeight.w500)
                : context.bullType.label.copyWith(
                    color: context.bull.textMuted,
                    fontWeight: FontWeight.w400,
                  ),
          ),
        ),
        const Gap(BullSpacing.md),
        Flexible(
          child: Align(alignment: Alignment.centerRight, child: child),
        ),
      ],
    ),
  );
}
