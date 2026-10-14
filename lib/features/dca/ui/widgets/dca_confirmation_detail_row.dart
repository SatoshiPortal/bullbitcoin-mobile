import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show BullShimmerLine;

class DcaConfirmationDetailRow extends StatelessWidget {
  final String label;
  final String? value;

  const DcaConfirmationDetailRow({super.key, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: .spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),

          Expanded(
            child: value == null
                ? const BullShimmerLine()
                : Text(
                    value!,
                    textAlign: .end,
                    style: theme.textTheme.bodyMedium,
                  ),
          ),
        ],
      ),
    );
  }
}
