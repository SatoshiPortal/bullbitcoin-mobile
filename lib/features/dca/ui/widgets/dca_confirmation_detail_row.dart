import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:flutter/material.dart';

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
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.appColors.onSurface,
            ),
          ),

          Expanded(
            child: value == null
                ? const LoadingLineContent()
                : Text(
                    value!,
                    textAlign: .end,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.appColors.outlineVariant,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
