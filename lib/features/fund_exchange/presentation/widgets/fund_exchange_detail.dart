import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:flutter/services.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';

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
    return Column(
      mainAxisAlignment: .center,
      crossAxisAlignment: .start,
      children: [
        BullText(label, style: context.bullText.bodyMedium),
        if (helpText != null) ...[
          const Gap(4.0),
          BullText(
            helpText!,
            style: context.bullText.labelMedium,
            color: context.bull.outline,
          ),
        ],
        const Gap(8.0),
        ListTile(
          title: value != null
              ? BullText(value!, style: context.bullText.bodyLarge)
              : const LoadingLineContent(),
          trailing: IconButton(
            onPressed: value != null
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
