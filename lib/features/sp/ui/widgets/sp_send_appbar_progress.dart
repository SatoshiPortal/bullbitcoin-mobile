import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/features/sp/presentation/sp_send_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_send_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Thin linear progress bar for a send-page app bar, shown while the send cubit
/// is loading. Shared by the three send pages.
class SpSendAppBarProgress extends StatelessWidget
    implements PreferredSizeWidget {
  const SpSendAppBarProgress({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(3);

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SpSendCubit, SpSendState, bool>(
      selector: (s) => s.isLoading,
      builder: (context, isLoading) => isLoading
          ? FadingLinearProgress(
              height: 3,
              trigger: isLoading,
              backgroundColor: context.appColors.surface,
              foregroundColor: context.appColors.primary,
            )
          : const SizedBox(height: 3),
    );
  }
}
