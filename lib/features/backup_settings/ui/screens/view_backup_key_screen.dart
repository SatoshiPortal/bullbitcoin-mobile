import 'dart:async';

import 'package:bb_mobile/core/mixins/privacy_screen.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ViewBackupKeyScreen extends StatefulWidget {
  final String backupFile;

  const ViewBackupKeyScreen({super.key, required this.backupFile});

  @override
  State<ViewBackupKeyScreen> createState() => _ViewBackupKeyScreenState();
}

class _ViewBackupKeyScreenState extends State<ViewBackupKeyScreen>
    with PrivacyScreen {
  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: enableScreenPrivacy(),
      builder: (context, snapshot) {
        return BlocProvider(
          create:
              (context) =>
                  locator<BackupSettingsCubit>()
                    ..viewVaultKey(widget.backupFile),
          child: const _Screen(),
        );
      },
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BackupSettingsCubit, BackupSettingsState>(
      listenWhen:
          (previous, current) =>
              previous.error != current.error && current.error != null ||
              previous.derivedBackupKey != current.derivedBackupKey ||
              previous.status != current.status,
      listener: (context, state) {
        if (state.error != null) {
          log.severe('Failed to derive backup key: ${state.error}');
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            forceMaterialTransparency: true,
            automaticallyImplyLeading: false,
            flexibleSpace: TopBar(
              title: 'Backup Key',
              onBack: () => context.pop(),
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (state.status == BackupSettingsStatus.viewingKey) ...[
                  FadingLinearProgress(
                    trigger: state.status == BackupSettingsStatus.viewingKey,
                    backgroundColor: context.colour.secondary,
                    height: 3,
                    foregroundColor: context.colour.primary,
                  ),
                ] else ...[
                  const Spacer(),
                  if (state.derivedBackupKey != null) ...[
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: CopyInput(
                        text:
                            state.derivedBackupKey != null &&
                                    state.derivedBackupKey!.length >= 6
                                ? state.derivedBackupKey!.substring(0, 6) +
                                    '*' * (state.derivedBackupKey!.length - 6)
                                : '',
                        canShowValueModal: true,
                        maxLines: 1,

                        clipboardText: state.derivedBackupKey,
                        overflow: TextOverflow.clip,
                        modalContent:
                            state.derivedBackupKey
                                ?.replaceAllMapped(
                                  RegExp('.{1,4}'),
                                  (match) => '${match.group(0)} ',
                                )
                                .trim(),
                      ),
                    ),
                  ],
                  if (state.error != null) ...[
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: context.colour.error,
                    ),
                    const Gap(16),
                    BBText(
                      'Failed to derive the backup key',
                      style: context.font.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const Spacer(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
