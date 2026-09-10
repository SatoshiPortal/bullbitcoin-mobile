import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/backup_settings/presentation/data_backup_setup_banner_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Home-page row for Data Backup while it is being set up after onboarding:
/// a progress line while the server is asked and a backup is restored, a
/// retry when the opt-in was refused. Hidden the rest of the time.
class DataBackupSetupBanner extends StatelessWidget {
  final Set<String> Function()? takeDefaultCreatedWalletIds;

  const DataBackupSetupBanner({super.key, this.takeDefaultCreatedWalletIds});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => locator<DataBackupSetupBannerCubit>()
      ..start(
        defaultCreatedWalletIds:
            takeDefaultCreatedWalletIds?.call() ?? const {},
      ),
    child: const _DataBackupSetupBannerView(),
  );
}

class _DataBackupSetupBannerView extends StatelessWidget {
  const _DataBackupSetupBannerView();

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<DataBackupSetupBannerCubit, DataBackupSetupBannerState>(
    builder: (context, state) => switch (state) {
      DataBackupSetupHidden() => const SizedBox.shrink(),
      DataBackupSettingUp() => _Row(
        leading: const _Spinner(),
        text: context.loc.homeDataBackupSettingUp,
      ),
      DataBackupRestoring() => _Row(
        leading: const _Spinner(),
        text: context.loc.homeDataBackupRestoring,
      ),
      DataBackupSetupFailed() => _Row(
        leading: Icon(Icons.cloud_off_outlined, color: context.appColors.error),
        text: context.loc.onboardingDataBackupEnableFailed,
        action: TextButton(
          onPressed: () =>
              context.read<DataBackupSetupBannerCubit>().applyPendingChoices(),
          child: Text(context.loc.homeDataBackupRetry),
        ),
        onTap: () => context.pushNamed(SettingsRoute.dataBackupSettings.name),
      ),
    },
  );
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

class _Row extends StatelessWidget {
  final Widget leading;
  final String text;
  final Widget? action;
  final VoidCallback? onTap;

  const _Row({
    required this.leading,
    required this.text,
    this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              leading,
              const Gap(12),
              Expanded(child: Text(text, style: context.font.bodyMedium)),
              ?action,
            ],
          ),
        ),
      ),
    ),
  );
}
