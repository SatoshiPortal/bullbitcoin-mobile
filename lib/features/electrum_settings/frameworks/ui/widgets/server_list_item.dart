import 'package:bull_ui/bull_ui.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/view_models/electrum_server_view_model.dart';

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
        context.appColors.success,
        context.loc.electrumServerOnline,
      ),
      ElectrumServerStatus.offline => (
        context.appColors.warning,
        context.loc.electrumServerOffline,
      ),
      ElectrumServerStatus.unknown => (
        context.appColors.textMuted,
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
