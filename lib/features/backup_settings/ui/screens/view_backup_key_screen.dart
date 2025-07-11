import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/loading/fading_linear_progress.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ViewBackupKeyScreen extends StatefulWidget {
  final String backupFile;

  const ViewBackupKeyScreen({super.key, required this.backupFile});

  @override
  State<ViewBackupKeyScreen> createState() => _ViewBackupKeyScreenState();
}

class _ViewBackupKeyScreenState extends State<ViewBackupKeyScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (context) =>
              locator<BackupSettingsCubit>()..viewVaultKey(widget.backupFile),
      child: const _Screen(),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BackupSettingsCubit, BackupSettingsState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error.toString())));
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
                FadingLinearProgress(
                  trigger: state.status == BackupSettingsStatus.viewingKey,
                  backgroundColor: context.colour.surface,
                  foregroundColor: context.colour.primary,
                ),
                const Spacer(),

                if (state.derivedBackupKey != null) ...[
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: SelectableText(
                      state.derivedBackupKey!,
                      textAlign: TextAlign.center,
                      style: context.font.displaySmall,
                    ),
                  ),
                ],
                if (state.error != null) ...[
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: context.colour.error,
                  ),
                  // error text
                  const Gap(16),
                  const Text(
                    'Failed to derive backup key',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Gap(8),
                  Text(
                    state.error.toString(),
                    style: TextStyle(color: context.colour.error, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
                const Spacer(),
                // Bottom button
                if (state.derivedBackupKey != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: 48,
                    ),
                    child: BBButton.big(
                      label: 'Copy to Clipboard',
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: state.derivedBackupKey!),
                        );
                      },
                      bgColor: context.colour.secondary,

                      textColor: context.colour.onPrimary,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
