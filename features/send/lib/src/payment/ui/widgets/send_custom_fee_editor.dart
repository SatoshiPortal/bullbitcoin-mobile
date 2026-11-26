import 'package:bull_ui/bull_ui.dart';

/// Controlled fee entry. [onSubmit] applies the value from Done on the iOS
/// keyboard bar, the app's usual one, since the iOS number pad has no check
/// key, or from the keyboard check on Android. Null leaves both inert, and
/// Done then only closes the keyboard. No transaction state lives inside this
/// view.
class SendCustomFeeEditor extends StatelessWidget {
  const SendCustomFeeEditor({
    super.key,
    required this.title,
    required this.backLabel,
    required this.closeLabel,
    required this.modes,
    required this.selectedMode,
    required this.value,
    required this.unit,
    required this.help,
    required this.doneLabel,
    required this.onMode,
    required this.onChanged,
    required this.onBack,
    required this.onClose,
    required this.onSubmit,
    this.focusNode,
    this.error,
    this.warning,
  });

  final String title;
  final String backLabel;
  final String closeLabel;
  final Set<String> modes;
  final String selectedMode;
  final String value;
  final String unit;
  final String help;
  final String doneLabel;
  final ValueChanged<String> onMode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBack;
  final VoidCallback onClose;
  final ValueChanged<String>? onSubmit;
  final FocusNode? focusNode;
  final String? error;
  final String? warning;

  @override
  Widget build(BuildContext context) => BullKeyboardActions(
    doneText: doneLabel,
    disableScroll: true,
    onDone: switch (onSubmit) {
      final submit? => () => submit(value),
      null => null,
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: BullSpacing.md),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                BullInlineIconButton(
                  onPressed: onBack,
                  tooltip: backLabel,
                  icon: const BullIcon(BullIcons.arrowBack),
                ),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: context.bullType.subtitle,
                  ),
                ),
                BullInlineIconButton(
                  onPressed: onClose,
                  tooltip: closeLabel,
                  icon: const BullIcon(BullIcons.close),
                ),
              ],
            ),
            const Gap(BullSpacing.sm),
            BullSegmented(
              items: modes,
              initialValue: selectedMode,
              onSelected: onMode,
              height: BullSpacing.xxl,
              fitLabels: true,
            ),
            const Gap(BullSpacing.sm),
            BullInputText(
              value: value,
              onChanged: onChanged,
              focusNode: focusNode,
              onlyNumbers: true,
              digitsOnly: false,
              maxLines: 1,
              onEditingComplete: onSubmit == null ? () {} : null,
              suffixText: unit,
              suffixStyle: context.bullType.body.copyWith(
                color: context.bull.textMuted,
              ),
              style: context.bullType.headline,
              onDone: onSubmit,
            ),
            const Gap(BullSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                error ?? help,
                style: context.bullType.label.copyWith(
                  color: error == null
                      ? context.bull.textMuted
                      : context.bull.error,
                ),
              ),
            ),
            if (warning case final message?) ...[
              const Gap(BullSpacing.xs),
              Text(
                message,
                style: context.bullType.label.copyWith(
                  color: context.bull.warning,
                ),
              ),
            ],
            const Gap(BullSpacing.md),
          ],
        ),
      ),
    ),
  );
}
