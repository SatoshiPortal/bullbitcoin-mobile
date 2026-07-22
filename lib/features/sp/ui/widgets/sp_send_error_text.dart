import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/presentation/sp_failure_l10n.dart';
import 'package:flutter/material.dart';

/// Inline localized error under a send page, or nothing when [failure] is null.
/// Shared by the three send pages; the call site selects the failure from the
/// send cubit.
class SpSendErrorText extends StatelessWidget {
  const SpSendErrorText({super.key, required this.failure});

  final SpFailure? failure;

  @override
  Widget build(BuildContext context) {
    final failure = this.failure;
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
  }
}
