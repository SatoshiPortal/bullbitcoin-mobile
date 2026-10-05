import 'package:bull_ui/bull_ui.dart';

final class LimitOrderDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const LimitOrderDetailRow({
    required this.label,
    required this.value,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: BullSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        Expanded(child: Text(value, textAlign: TextAlign.end, maxLines: 5)),
      ],
    ),
  );
}
