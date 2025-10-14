import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/share_logs_widget.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class LogSettingsScreen extends StatelessWidget {
  const LogSettingsScreen({super.key});

  Future<void> _confirmDeleteLogs(BuildContext context) async {
    await BlurredBottomSheet.show(
      context: context,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.3,
        ),
        decoration: BoxDecoration(
          color: context.colour.onPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const Gap(16),
              BBText('Delete logs', style: context.font.headlineMedium),
              const Gap(16),
              BBText(
                'Are you sure you want to delete all logs? This action cannot be undone.',
                style: context.font.bodyMedium,
              ),
              const Gap(16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  BBButton.small(
                    onPressed: () => context.pop(),
                    label: 'Cancel',
                    bgColor: context.colour.secondary,
                    textColor: context.colour.onSecondary,
                  ),
                  BBButton.small(
                    onPressed: () async {
                      context.pop();
                      await log.deleteLogs();
                    },
                    label: 'Delete',
                    bgColor: context.colour.primary,
                    textColor: context.colour.onPrimary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logs')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const ShareLogsWidget(),
              const Gap(16),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                ),
                tileColor: Colors.transparent,
                title: const Text('Delete logs'),
                onTap: () => _confirmDeleteLogs(context),
                trailing: const Icon(Icons.delete_sharp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
