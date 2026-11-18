import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart' show BullShimmerLine, BullTypographyX;

class DcaConfirmationDetailRow extends StatelessWidget {
  final String label;
  final String? value;

  const DcaConfirmationDetailRow({super.key, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: .spaceBetween,
        children: [
          Text(label, style: context.bullType.body),

          Expanded(
            child: value == null
                ? const BullShimmerLine()
                : Text(value!, textAlign: .end, style: context.bullType.body),
          ),
        ],
      ),
    );
  }
}
