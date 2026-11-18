import 'package:bb_mobile/core/mempool/application/dtos/mempool_server_dto.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_status.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/mempool_settings/presentation/mempool_server_encryption.dart';
import 'package:bull_ui/bull_ui.dart' show BullServerTile;
import 'package:material_ui/material_ui.dart';

class MempoolServerItem extends StatelessWidget {
  const MempoolServerItem({
    super.key,
    required this.server,
    this.disabled = false,
    this.onDelete,
  });

  final MempoolServerDto server;
  final bool disabled;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (server.status) {
      MempoolServerStatus.online => (
        context.appColors.success,
        context.loc.mempoolServerStatusOnline,
      ),
      MempoolServerStatus.offline => (
        context.appColors.warning,
        context.loc.mempoolServerStatusOffline,
      ),
      MempoolServerStatus.checking => (
        context.appColors.textMuted,
        context.loc.mempoolServerStatusChecking,
      ),
      MempoolServerStatus.unknown => (
        context.appColors.textMuted,
        context.loc.mempoolServerStatusUnknown,
      ),
    };

    return BullServerTile(
      title: server.url,
      statusColor: color,
      statusLabel: label,
      badgeLabel: server.isEncrypted
          ? context.loc.serverEncrypted
          : context.loc.serverUnencrypted,
      badgeIsWarning: !server.isEncrypted,
      disabled: disabled,
      disabledLabel: context.loc.electrumServerNotUsed,
      onDelete: onDelete,
      deleteTooltip: context.loc.delete,
    );
  }
}
