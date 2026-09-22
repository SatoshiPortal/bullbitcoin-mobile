import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/wizard/ui/wizard_page.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/wizard_step_layout.dart';
import 'package:flutter/material.dart';

class DataBackupStep extends StatelessWidget {
  const DataBackupStep({super.key});

  @override
  Widget build(BuildContext context) => WizardStepLayout(
    page: WizardPage.dataBackup,
    title: context.loc.dataBackupTitle,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          context.loc.dataBackupConsentBody,
          style: context.font.bodyMedium,
        ),
        const SizedBox(height: 20),
        BBText(
          context.loc.dataBackupConsentTitle,
          style: context.font.titleMedium,
        ),
        const SizedBox(height: 64),
      ],
    ),
  );
}
