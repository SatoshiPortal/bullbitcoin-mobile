import 'package:bull_ui/bull_ui.dart';

/// Recipient and amount share a page; the screen owner supplies verified views
/// and callbacks without exposing wallet entities to the layout.
class SendPaymentPage extends StatelessWidget {
  const SendPaymentPage({
    super.key,
    required this.title,
    required this.stepLabels,
    required this.stepSemanticLabel,
    required this.recipientLabel,
    required this.recipient,
    required this.amountLabel,
    required this.lockedAmountLabel,
    required this.amount,
    required this.balance,
    required this.fromLabel,
    required this.walletLabel,
    required this.walletColor,
    required this.walletActionLabel,
    required this.maxLabel,
    required this.settingsLabel,
    required this.feeSummary,
    required this.continueLabel,
    required this.onBack,
    required this.onSettings,
    required this.onMax,
    required this.onWallet,
    required this.onContinue,
    this.recipientReady = false,
    this.isBusy = false,
  });

  final String title;
  final List<String> stepLabels;
  final String Function(int, String) stepSemanticLabel;
  final String recipientLabel;
  final Widget recipient;
  final String amountLabel;
  final String lockedAmountLabel;
  final Widget amount;
  final Widget balance;
  final String fromLabel;
  final String walletLabel;
  final Color walletColor;
  final String walletActionLabel;
  final String maxLabel;
  final String settingsLabel;
  final String feeSummary;
  final String continueLabel;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback? onMax;
  final VoidCallback? onWallet;
  final VoidCallback? onContinue;
  final bool recipientReady;
  final bool isBusy;

  @override
  Widget build(BuildContext context) => BullScaffold(
    backgroundColor: context.bull.background,
    resizeToAvoidBottomInset: true,
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BullTopBar(title: title, onBack: onBack),
          BullStepBar(
            labels: stepLabels,
            currentStep: recipientReady ? 1 : 0,
            semanticLabel: stepSemanticLabel,
          ),
          Expanded(
            child: SingleChildScrollView(
              reverse:
                  recipientReady && MediaQuery.viewInsetsOf(context).bottom > 0,
              padding: const EdgeInsets.all(BullSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(recipientLabel, style: context.bullType.body),
                  const Gap(BullSpacing.xs),
                  recipient,
                  const Gap(BullSpacing.lg),
                  Text(
                    amountLabel,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Gap(BullSpacing.xs),
                  if (recipientReady) ...[
                    amount,
                    const Gap(BullSpacing.md),
                    Row(
                      children: [
                        Expanded(child: balance),
                        Padding(
                          padding: const EdgeInsets.only(right: BullSpacing.xs),
                          child: BullFieldAction(
                            label: maxLabel,
                            onPressed: onMax,
                          ),
                        ),
                      ],
                    ),
                    const Gap(BullSpacing.xs),
                    Text(fromLabel, style: context.bullType.body),
                    const Gap(BullSpacing.xs),
                    Semantics(
                      button: true,
                      enabled: onWallet != null,
                      label: walletActionLabel,
                      value: walletLabel,
                      onTap: onWallet,
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: onWallet,
                        child: Container(
                          padding: const EdgeInsets.all(BullSpacing.xs),
                          decoration: BoxDecoration(
                            color: context.bull.surface,
                            border: Border(
                              left: BorderSide(color: walletColor, width: 4),
                              top: BorderSide(color: context.bull.border),
                              right: BorderSide(color: context.bull.border),
                              bottom: BorderSide(color: context.bull.border),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: BullSpacing.xs,
                                  ),
                                  child: Text(
                                    walletLabel,
                                    style: context.bullType.body,
                                  ),
                                ),
                              ),
                              ExcludeSemantics(
                                child: BullFieldAction(
                                  label: walletActionLabel,
                                  icon: BullIcons.expandMore,
                                  onPressed: onWallet,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ] else
                    Container(
                      padding: const EdgeInsets.all(BullSpacing.md),
                      decoration: BoxDecoration(
                        color: context.bull.surface,
                        border: Border.all(color: context.bull.border),
                        borderRadius: BorderRadius.circular(
                          context.bullShapes.input,
                        ),
                      ),
                      child: Row(
                        children: [
                          BullIcon(
                            BullIcons.lock,
                            color: context.bull.textMuted,
                          ),
                          const Gap(BullSpacing.xs),
                          Expanded(
                            child: Text(
                              lockedAmountLabel,
                              style: context.bullType.label.copyWith(
                                color: context.bull.textMuted,
                              ),
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
            padding: const EdgeInsets.fromLTRB(
              BullSpacing.md,
              0,
              BullSpacing.md,
              BullSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (MediaQuery.viewInsetsOf(context).bottom == 0) ...[
                  BullSettingsEntryTile(
                    label: settingsLabel,
                    summary: feeSummary,
                    onPressed: onSettings,
                  ),
                  const Gap(BullSpacing.md),
                ],
                BullButton.primary(
                  label: continueLabel,
                  onPressed: isBusy || !recipientReady ? null : onContinue,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
