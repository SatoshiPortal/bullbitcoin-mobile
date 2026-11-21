import '../../../network_l10n.dart';
import '../../presentation/mempool_settings_cubit.dart';
import 'mempool_server_item.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullThemeX, BullConfirmDialog, BullTypographyX;

class MempoolServerList extends StatelessWidget {
  const MempoolServerList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MempoolSettingsCubit, MempoolSettingsState>(
      builder: (context, state) {
        final defaultServer = state.defaultServer;
        final customServer = state.customServer;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.loc.mempoolSettingsDefaultServer,
              style: context.bullType.label.copyWith(
                color: context.bull.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            if (defaultServer != null)
              MempoolServerItem(
                server: defaultServer,
                disabled: customServer != null,
              ),
            if (customServer != null) ...[
              const SizedBox(height: 16),
              Text(
                context.loc.mempoolSettingsCustomServer,
                style: context.bullType.label.copyWith(
                  color: context.bull.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              MempoolServerItem(
                server: customServer,
                onDelete: state.isProcessing
                    ? null
                    : () => _showDeleteConfirmation(context),
              ),
            ],
          ],
        );
      },
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
