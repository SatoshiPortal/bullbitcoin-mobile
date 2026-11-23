import '../../presentation/mempool_server_row.dart';

import '../../../network_l10n.dart';
import '../../presentation/mempool_server_encryption.dart';

import 'package:bull_ui/bull_ui.dart' show BullThemeX, BullServerTile;
import 'package:material_ui/material_ui.dart';

class MempoolServerItem extends StatelessWidget {
  const MempoolServerItem({
    super.key,
    required this.row,
    this.disabled = false,
    this.onDelete,
  });

  final MempoolServerRow row;
  final bool disabled;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (row.status) {
      MempoolServerStatus.online => (
        context.bull.success,
        context.loc.mempoolServerStatusOnline,
      ),
      MempoolServerStatus.offline => (
        context.bull.warning,
        context.loc.mempoolServerStatusOffline,
      ),
      MempoolServerStatus.checking => (
        context.bull.textMuted,
        context.loc.mempoolServerStatusChecking,
      ),
      MempoolServerStatus.unknown => (
        context.bull.textMuted,
        context.loc.mempoolServerStatusUnknown,
      ),
    };

    return BullServerTile(
      title: row.server.url,
      statusColor: color,
      statusLabel: label,
      badgeLabel: row.server.isEncrypted
          ? context.loc.serverEncrypted
          : context.loc.serverUnencrypted,
      badgeIsWarning: !row.server.isEncrypted,
      disabled: disabled,
      disabledLabel: context.loc.electrumServerNotUsed,
      onDelete: onDelete,
      deleteTooltip: context.loc.delete,
    );
  }
}
