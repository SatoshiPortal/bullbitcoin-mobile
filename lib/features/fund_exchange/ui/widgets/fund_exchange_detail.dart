import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

class FundExchangeDetail extends StatelessWidget {
  const FundExchangeDetail({
    super.key,
    required this.label,
    this.helpText,
    this.value,
  });

  final String label;
  final String? helpText;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        if (helpText != null) ...[
          const Gap(4.0),
          Text(
            helpText!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
        const Gap(8.0),
        ListTile(
          title: value != null ? Text(value!) : const LoadingLineContent(),
          trailing: IconButton(
            onPressed:
                value != null
                    ? () {
                      final data = ClipboardData(text: value!);
                      Clipboard.setData(data);
                    }
                    : null,
            icon: const Icon(Icons.copy),
          ),
        ),
      ],
    );
  }
}
