import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:flutter/material.dart';

class GetPaidAdvancedSettingsButton extends StatelessWidget {
  final String label;
  final WidgetBuilder sheetBuilder;

  const GetPaidAdvancedSettingsButton({
    super.key,
    required this.label,
    required this.sheetBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      child: TextButton(
        onPressed: () => BlurredBottomSheet.show(
          context: context,
          child: sheetBuilder(context),
        ),
        child: Text(label, style: TextStyle(color: context.appColors.error)),
      ),
    );
  }
}
