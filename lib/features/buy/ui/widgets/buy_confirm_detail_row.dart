import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:flutter/material.dart';

class BuyConfirmDetailRow extends StatelessWidget {
  final String label;
  final String? value;

  const BuyConfirmDetailRow({super.key, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.surfaceContainer,
            ),
          ),

          Expanded(
            child:
                value == null
                    ? const LoadingLineContent()
                    : Text(
                      value!,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
