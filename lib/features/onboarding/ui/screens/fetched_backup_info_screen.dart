import 'package:bb_mobile/core/recoverbull/domain/entity/backup_info.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/key_server.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/key_server/ui/key_server_router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class FetchedBackupInfoScreen extends StatelessWidget {
  final BackupInfo encryptedInfo;
  const FetchedBackupInfoScreen({super.key, required this.encryptedInfo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () => context.pop(),
          title: 'Recover Wallet',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BBText(
              'Your vault was successfully imported',
              textAlign: TextAlign.left,
              style: context.font.bodySmall,
            ),
            const Gap(16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: context.colour.surface),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _KeyValueRow(label: 'Backup ID:', value: encryptedInfo.id),
                  const Gap(8),
                  _KeyValueRow(
                    label: 'Created at:',
                    value: DateFormat(
                      "yyyy-MMM-dd, HH:mm:ss",
                    ).format(encryptedInfo.createdAt.toLocal()),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Center(
              child: BBButton.big(
                label: 'Enter Backup key manually >>',
                onPressed:
                    () => context.push(
                      KeyServerRoute.keyServerFlow.path,
                      extra: (
                        encryptedInfo.backupFile,
                        CurrentKeyServerFlow.recoveryWithBackupKey.name,
                        true,
                      ),
                    ),
                bgColor: Colors.transparent,
                textStyle: context.font.bodySmall,
                textColor: context.colour.inversePrimary,
              ),
            ),
            const Gap(16),
            BBButton.big(
              label: 'Decrypt vault',
              onPressed:
                  () => context.pushNamed(
                    KeyServerRoute.keyServerFlow.name,
                    extra: (
                      encryptedInfo.backupFile,
                      CurrentKeyServerFlow.recovery.name,
                      true,
                    ),
                  ),
              bgColor: context.colour.secondary,
              textColor: context.colour.onSecondary,
            ),
          ],
        ),
      ),
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
