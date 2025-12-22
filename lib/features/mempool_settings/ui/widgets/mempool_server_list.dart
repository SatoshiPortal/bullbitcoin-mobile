import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/mempool_settings/presentation/bloc/mempool_settings_cubit.dart';
import 'package:bb_mobile/features/mempool_settings/ui/widgets/mempool_server_item.dart';
import 'package:bb_mobile/features/mempool_settings/ui/widgets/set_custom_server_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class MempoolServerList extends StatelessWidget {
  const MempoolServerList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MempoolSettingsCubit, MempoolSettingsState>(
      builder: (context, state) {
        final defaultServer = state.defaultServer;
        final customServer = state.customServer;
        final isProcessing =
            state.isSavingServer ||
            state.isDeletingServer ||
            state.isUpdatingSettings;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.loc.mempoolSettingsDefaultServer,
              style: context.font.titleSmall?.copyWith(
                color: context.appColors.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            if (defaultServer != null)
              MempoolServerItem(
                server: defaultServer,
                disabled: customServer != null,
                useForFeeEstimation:
                    state.settings?.useForFeeEstimation ?? true,
                isProcessing: isProcessing,
                onFeeEstimationChanged: (value) {
                  context
                      .read<MempoolSettingsCubit>()
                      .updateUseForFeeEstimation(value);
                },
              ),
            if (customServer != null) ...[
              const SizedBox(height: 16),
              Text(
                context.loc.mempoolSettingsCustomServer,
                style: context.font.titleSmall?.copyWith(
                  color: context.appColors.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              MempoolServerItem(
                server: customServer,
                isCustom: true,
                useForFeeEstimation: state.settings?.useForFeeEstimation ?? true,
                isProcessing: isProcessing,
                onFeeEstimationChanged: (value) {
                  context
                      .read<MempoolSettingsCubit>()
                      .updateUseForFeeEstimation(value);
                },
                onDelete: () => _showDeleteConfirmation(context),
                onEdit: () => _showEditServerSheet(context, customServer.url),
              ),
            ],
            const Gap(16),
            if (customServer == null)
              TextButton.icon(
                onPressed: isProcessing
                    ? null
                    : () => _showAddServerSheet(context),
                icon: Icon(
                  Icons.add_circle_outline,
                  color: context.appColors.primary,
                ),
                label: Text(
                  context.loc.mempoolCustomServerAdd,
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.primary,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showAddServerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) => BlocProvider.value(
        value: context.read<MempoolSettingsCubit>(),
        child: const SetCustomServerBottomSheet(),
      ),
    );
  }

  void _showEditServerSheet(BuildContext context, String currentUrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) => BlocProvider.value(
        value: context.read<MempoolSettingsCubit>(),
        child: SetCustomServerBottomSheet(initialUrl: currentUrl),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.loc.mempoolCustomServerDeleteTitle),
        content: Text(context.loc.mempoolCustomServerDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.loc.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<MempoolSettingsCubit>().deleteCustomServer();
            },
            child: Text(
              context.loc.delete,
              style: TextStyle(color: context.appColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
