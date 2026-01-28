import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
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
                onEdit: () => _showEditServerSheet(context, customServer.url, customServer.enableSsl),
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
    SetCustomServerBottomSheet.show(context);
  }

  void _showEditServerSheet(BuildContext context, String currentUrl, bool enableSsl) {
    SetCustomServerBottomSheet.show(
      context,
      initialUrl: currentUrl,
      initialEnableSsl: enableSsl,
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.appColors.surface,
        title: Text(context.loc.mempoolCustomServerDeleteTitle),
        content: Text(
          context.loc.mempoolCustomServerDeleteMessage,
          style: context.font.bodyMedium,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: BBButton.small(
                  label: context.loc.cancel,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  bgColor: context.appColors.transparent,
                  outlined: true,
                  textStyle: context.font.headlineLarge,
                  textColor: context.appColors.secondary,
                ),
              ),
              const Gap(12),
              Expanded(
                child: BBButton.small(
                  label: context.loc.delete,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    context.read<MempoolSettingsCubit>().deleteCustomServer();
                  },
                  bgColor: context.appColors.error,
                  textStyle: context.font.headlineLarge,
                  textColor: context.appColors.onPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
