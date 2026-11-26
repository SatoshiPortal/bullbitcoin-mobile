import 'package:bull_ui/bull_ui.dart';
import 'package:electrum/electrum.dart';

import '../../../network_l10n.dart';
import '../../presentation/electrum_server_view_model.dart';

class ServerListItem extends StatelessWidget {
  const ServerListItem({
    super.key,
    required this.server,
    this.isDraggable = false,
    this.disabled = false,
    this.onDelete,
  });

  final ElectrumServerViewModel server;
  final bool isDraggable;
  final bool disabled;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (server.status) {
      ElectrumServerStatus.online => (
        context.bull.success,
        context.loc.electrumServerOnline,
      ),
      ElectrumServerStatus.offline => (
        context.bull.warning,
        context.loc.electrumServerOffline,
      ),
      ElectrumServerStatus.unknown => (
        context.bull.textMuted,
        context.loc.statusCheckUnknown,
      ),
    };

    return BullServerTile(
      title: server.displayName,
      statusColor: color,
      statusLabel: label,
      badgeLabel: server.isEncrypted
          ? context.loc.serverEncrypted
          : context.loc.serverUnencrypted,
      badgeIsWarning: !server.isEncrypted,
      showDragHandle: isDraggable,
      disabled: disabled,
      disabledLabel: context.loc.electrumServerNotUsed,
      onDelete: onDelete,
      deleteTooltip: context.loc.electrumDelete,
    );
  }
}
