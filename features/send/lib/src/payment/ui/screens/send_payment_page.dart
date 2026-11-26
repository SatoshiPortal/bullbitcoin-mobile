import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart' show FocusScope;

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
    required this.amount,
    required this.balance,
    required this.fromLabel,
    required this.wallet,
    required this.maxLabel,
    required this.settingsLabel,
    required this.feeSummary,
    required this.continueLabel,
    required this.onBack,
    required this.onSettings,
    required this.onMax,
    required this.onContinue,
    this.recipientReady = false,
    this.isBusy = false,
    this.showMax = true,
    this.showSettings = true,
    this.extra,
  });

  final String title;
  final List<String> stepLabels;
  final String Function(int, String) stepSemanticLabel;
  final String recipientLabel;
  final Widget recipient;
  final String amountLabel;
  final Widget amount;
  final Widget balance;
  final String fromLabel;

  /// The source wallet picker, shown under the recipient once it is valid.
  final Widget wallet;
  final String maxLabel;
  final String settingsLabel;
  final String feeSummary;
  final String continueLabel;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback? onMax;
  final VoidCallback? onContinue;
  final bool recipientReady;
  final bool isBusy;
  final bool showMax;
  final bool showSettings;
  final Widget? extra;

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
            // Tapping outside a field closes the keyboard: the iOS number pad
            // has no key to do it.
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                reverse:
                    recipientReady &&
                    MediaQuery.viewInsetsOf(context).bottom > 0,
                padding: const EdgeInsets.all(BullSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(recipientLabel, style: context.bullType.body),
                    const Gap(BullSpacing.xs),
                    recipient,
                    if (recipientReady) ...[
                      const Gap(BullSpacing.lg),
                      Text(fromLabel, style: context.bullType.body),
                      const Gap(BullSpacing.xs),
                      wallet,
                      const Gap(BullSpacing.lg),
                      Text(
                        amountLabel,
                        style: context.bullType.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Gap(BullSpacing.xs),
                      amount,
                      const Gap(BullSpacing.md),
                      Row(
                        children: [
                          Expanded(child: balance),
                          if (showMax)
                            Padding(
                              padding: const EdgeInsets.only(
                                right: BullSpacing.xs,
                              ),
                              child: BullFieldAction(
                                label: maxLabel,
                                onPressed: onMax,
                              ),
                            ),
                        ],
                      ),
                      if (extra case final widget?) ...[
                        const Gap(BullSpacing.md),
                        widget,
                      ],
                    ],
                  ],
                ),
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
                if (showSettings &&
                    MediaQuery.viewInsetsOf(context).bottom == 0) ...[
                  BullSettingsEntryTile(
                    label: settingsLabel,
                    summary: feeSummary,
                    onPressed: onSettings,
                  ),
                  const Gap(BullSpacing.md),
                ],
                BullButton.primary(
                  label: continueLabel,
                  onPressed: isBusy ? null : onContinue,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
