import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ErrorReportingConfirmationBottomSheet extends StatelessWidget {
  const ErrorReportingConfirmationBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return BlurredBottomSheet.show(
      context: context,
      child: const ErrorReportingConfirmationBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.appColors.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Icon(
                  Icons.bug_report,
                  size: 48,
                  color: context.appColors.primary,
                ),
                const SizedBox(height: 16),
                BBText(
                  context.loc.errorReportingProgramTitle,
                  style: context.font.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                BBText(
                  context.loc.errorReportingProgramDescription,
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.secondary.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: BBButton.big(
                        label: context.loc.errorReportingCancelButton,
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        bgColor: context.appColors.surface,
                        textColor: context.appColors.text,
                        borderColor: context.appColors.border,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BBButton.big(
                        label: context.loc.errorReportingAcceptButton,
                        onPressed: () {
                          context.read<SettingsCubit>().toggleErrorReporting(
                            true,
                          );
                          Navigator.of(context).pop();
                          SnackBarUtils.showSnackBar(
                            context,
                            context.loc.errorReportingRestartSnackbar,
                          );
                        },
                        bgColor: context.appColors.primary,
                        textColor: context.appColors.onPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
