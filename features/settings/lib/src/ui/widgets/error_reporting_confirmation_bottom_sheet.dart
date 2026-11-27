import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:settings/src/l10n.dart';
import 'package:settings/src/presentation/bloc/settings_cubit.dart';
import 'package:settings/src/ui/widgets/settings_restart_dialog.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ErrorReportingConfirmationBottomSheet extends StatelessWidget {
  const ErrorReportingConfirmationBottomSheet({super.key});

  static Future<void> show(BuildContext context) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final settings = context.read<SettingsCubit>();
    final message = context.loc.errorReportingRestartSnackbar;
    final accepted = await BullBottomSheet.show<bool>(
      context: context,
      child: const ErrorReportingConfirmationBottomSheet(),
    );
    if (accepted != true) return;
    final saved = await settings.toggleErrorReporting(true);
    if (!saved || !navigator.mounted) return;
    await showSettingsRestartDialog(navigator.context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
                  borderRadius: BorderRadius.circular(context.bullShapes.dot),
                ),
              ),
              const SizedBox(height: 24),
              Icon(
                Icons.bug_report,
                size: 48,
                color: context.appColors.primary,
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: BullText(
                  context.loc.errorReportingProgramTitle,
                  style: context.bullType.subtitle.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.loc.errorReportingProgramDescriptionP1,
                style: context.bullType.body.copyWith(
                  color: context.appColors.secondary.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.justify,
              ),
              const SizedBox(height: 8),
              Text(
                context.loc.errorReportingProgramDescriptionP2,
                style: context.bullType.body.copyWith(
                  color: context.appColors.secondary.withValues(alpha: 0.7),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.justify,
              ),
              const SizedBox(height: 8),
              Text(
                context.loc.errorReportingProgramDescriptionP3,
                style: context.bullType.body.copyWith(
                  color: context.appColors.secondary.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.justify,
              ),
              const SizedBox(height: 8),
              Text(
                context.loc.errorReportingProgramDescriptionP4,
                style: context.bullType.body.copyWith(
                  color: context.appColors.secondary.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.justify,
              ),
              const SizedBox(height: 8),
              Text(
                context.loc.errorReportingProgramDescriptionP5,
                style: context.bullType.body.copyWith(
                  color: context.appColors.secondary.withValues(alpha: 0.7),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.justify,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: BullButton.secondary(
                      label: context.loc.errorReportingCancelButton,
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BullButton.primary(
                      label: context.loc.errorReportingAcceptButton,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
