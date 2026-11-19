import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullShimmerLine, Gap, BullTypographyX;

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
        BBText(label, style: context.bullType.body),
        if (helpText != null) ...[
          const Gap(4.0),
          BBText(
            helpText!,
            style: context.bullType.caption,
            color: context.appColors.outline,
          ),
        ],
        const Gap(8.0),
        ListTile(
          title: value != null
              ? BBText(
                  value!,
                  style: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                )
              : const BullShimmerLine(),
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
