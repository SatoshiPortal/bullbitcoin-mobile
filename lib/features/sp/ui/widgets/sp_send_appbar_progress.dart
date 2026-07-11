import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:flutter/material.dart';

/// Thin linear progress bar for a send-page app bar, shown while [isLoading].
/// Shared by the three send pages; the call site selects `isLoading` from the
/// send cubit.
class SpSendAppBarProgress extends StatelessWidget
    implements PreferredSizeWidget {
  const SpSendAppBarProgress({super.key, required this.isLoading});

  final bool isLoading;

  @override
  Size get preferredSize => const Size.fromHeight(3);

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? FadingLinearProgress(
            height: 3,
            trigger: isLoading,
            backgroundColor: context.appColors.surface,
            foregroundColor: context.appColors.primary,
          )
        : const SizedBox(height: 3);
  }
}
