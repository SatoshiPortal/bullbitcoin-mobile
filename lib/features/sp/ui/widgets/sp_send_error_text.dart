import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/presentation/sp_failure_l10n.dart';
import 'package:bb_mobile/features/sp/presentation/sp_send_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_send_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Inline localized error under a send page, or nothing when there is no
/// failure. Shared by the three send pages.
class SpSendErrorText extends StatelessWidget {
  const SpSendErrorText({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SpSendCubit, SpSendState, SpFailure?>(
      selector: (s) => s.error,
      builder: (context, failure) {
        if (failure == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            failure.toTranslated(context),
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.error,
            ),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}
