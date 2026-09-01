import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/wizard/ui/wizard_page.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/wizard_step_layout.dart';
import 'package:flutter/material.dart';

final class MetadataBackupStep extends StatelessWidget {
  const MetadataBackupStep({super.key});

  @override
  Widget build(BuildContext context) => WizardStepLayout(
    page: WizardPage.metadataBackup,
    title: context.loc.wizardMetadataBackupTitle,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          context.loc.wizardMetadataBackupBody,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        BBText(
          context.loc.wizardMetadataBackupQuestion,
          style: context.font.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
