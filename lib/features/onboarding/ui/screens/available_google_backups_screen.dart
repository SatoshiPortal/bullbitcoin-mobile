import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class AvailableGoogleBackupsScreen extends StatelessWidget {
  const AvailableGoogleBackupsScreen({super.key, required this.backups});
  final List<DriveFile> backups;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () => context.pop(),
          title: 'Available Backups',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: BackupsList(backups: backups))],
        ),
      ),
    );
  }
}

class BackupsList extends StatelessWidget {
  final List<DriveFile> backups;
  const BackupsList({required this.backups});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: backups.length,
      itemBuilder: (context, index) {
        final backup = backups[index];
        return GestureDetector(
          onTap: () {
            context.pushNamed(
              OnboardingRoute.fetchedBackupInfo.name,
              extra: backup.id,
            );
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _KeyValueRow(label: 'Backup ID:', value: backup.backupId),
                  const Gap(8),
                  _KeyValueRow(
                    label: 'Created at:',
                    value: DateFormat(
                      "yyyy-MMM-dd, HH:mm:ss",
                    ).format(backup.createdTime.toLocal()),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  const _KeyValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(label, style: context.font.bodyMedium),
        const SizedBox(width: 8),
        Expanded(
          child: BBText(value, style: context.font.bodyLarge, maxLines: 3),
        ),
      ],
    );
  }
}
