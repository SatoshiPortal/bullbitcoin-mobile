import 'package:bull_ui/bull_ui.dart';

class SendLeavePaymentDialog extends StatelessWidget {
  const SendLeavePaymentDialog({
    super.key,
    required this.title,
    required this.description,
    required this.cancelLabel,
    required this.openLabel,
    required this.onCancel,
    required this.onOpen,
  });
  final String title;
  final String description;
  final String cancelLabel;
  final String openLabel;
  final VoidCallback onCancel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: context.bullType.subtitle),
        const Gap(BullSpacing.sm),
        Text(description, style: context.bullType.body),
        const Gap(BullSpacing.lg),
        Row(
          children: [
            Expanded(
              child: BullButton.secondary(
                label: cancelLabel,
                onPressed: onCancel,
              ),
            ),
            const Gap(BullSpacing.sm),
            Expanded(
              child: BullButton.primary(label: openLabel, onPressed: onOpen),
            ),
          ],
        ),
      ],
    ),
  );
}
