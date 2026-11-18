import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/mempool_settings/presentation/bloc/mempool_settings_cubit.dart';
import 'package:bb_mobile/features/mempool_settings/ui/widgets/mempool_server_item.dart';
import 'package:bb_mobile/features/mempool_settings/ui/widgets/set_custom_server_bottom_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullConfirmDialog, Gap, BullTypographyX;

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
              style: context.bullType.label.copyWith(
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
                style: context.bullType.label.copyWith(
                  color: context.appColors.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              MempoolServerItem(
                server: customServer,
                isCustom: true,
                useForFeeEstimation:
                    state.settings?.useForFeeEstimation ?? true,
                isProcessing: isProcessing,
                onFeeEstimationChanged: (value) {
                  context
                      .read<MempoolSettingsCubit>()
                      .updateUseForFeeEstimation(value);
                },
                onDelete: () => _showDeleteConfirmation(context),
                onEdit: () => _showEditServerSheet(
                  context,
                  customServer.url,
                  customServer.enableSsl,
                ),
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
                  style: context.bullType.body.copyWith(
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

  void _showEditServerSheet(
    BuildContext context,
    String currentUrl,
    bool enableSsl,
  ) {
    SetCustomServerBottomSheet.show(
      context,
      initialUrl: currentUrl,
      initialEnableSsl: enableSsl,
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await BullConfirmDialog.show(
      context,
      title: context.loc.mempoolCustomServerDeleteTitle,
      message: context.loc.mempoolCustomServerDeleteMessage,
      confirmLabel: context.loc.delete,
      cancelLabel: context.loc.cancel,
      destructive: true,
    );
    if (confirmed && context.mounted) {
      await context.read<MempoolSettingsCubit>().deleteCustomServer();
    }
  }
}
