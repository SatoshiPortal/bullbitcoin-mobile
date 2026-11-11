import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart';

class BBErrorRetry extends StatelessWidget {
  const BBErrorRetry({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BullText(
          message,
          textAlign: TextAlign.center,
          style: context.font.bodyMedium,
          color: context.appColors.error,
        ),
        const Gap(8),
        BullButton.small(
          label: context.loc.retry,
          compact: true,
          onPressed: onRetry,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
      ],
    );
  }
}
