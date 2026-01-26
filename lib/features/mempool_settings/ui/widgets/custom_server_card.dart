import 'package:bb_mobile/core/mempool/application/dtos/mempool_server_dto.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/mempool_settings/presentation/bloc/mempool_settings_cubit.dart';
import 'package:bb_mobile/features/mempool_settings/ui/widgets/set_custom_server_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CustomServerCard extends StatelessWidget {
  final MempoolServerDto? customServer;
  final bool isProcessing;

  const CustomServerCard({
    super.key,
    this.customServer,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    if (customServer == null) {
      return _AddCustomServerButton(isProcessing: isProcessing);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customServer!.url,
                        style: context.font.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customServer!.fullUrl,
                        style: context.font.bodySmall?.copyWith(
                          color: context.appColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: customServer!.url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('URL copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () => _showEditServerSheet(context),
                  icon: const Icon(Icons.edit),
                  label: Text(context.loc.mempoolCustomServerEdit),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () => _showDeleteConfirmation(context),
                  icon: Icon(
                    Icons.delete,
                    color: context.appColors.error,
                  ),
                  label: Text(
                    context.loc.mempoolCustomServerDelete,
                    style: TextStyle(color: context.appColors.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditServerSheet(BuildContext context) {
    BlurredBottomSheet.show(
      context: context,
      child: BlocProvider.value(
        value: context.read<MempoolSettingsCubit>(),
        child: SetCustomServerBottomSheet(
          initialUrl: customServer!.url,
        ),
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

class _AddCustomServerButton extends StatelessWidget {
  final bool isProcessing;

  const _AddCustomServerButton({required this.isProcessing});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: isProcessing
            ? null
            : () {
                BlurredBottomSheet.show(
                  context: context,
                  child: BlocProvider.value(
                    value: context.read<MempoolSettingsCubit>(),
                    child: const SetCustomServerBottomSheet(),
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                color: context.appColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                context.loc.mempoolCustomServerAdd,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
