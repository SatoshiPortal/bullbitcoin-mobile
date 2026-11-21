import 'package:bb_mobile/core/electrum/domain/entities/electrum_settings.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_server.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';

/// Applies persisted settings to a server before resolving its Tor route.
ElectrumConnection configuredElectrumConnection({
  required ElectrumServer server,
  required ElectrumSettings settings,
  required ElectrumServerNetwork network,
}) => ElectrumConnection(
  url: server.url,
  retry: settings.retry,
  timeout: settings.timeout,
  stopGap: settings.stopGap,
  validateDomain: !server.isCustom || settings.validateDomain,
  isCustom: server.isCustom,
  // LWK does not support SOCKS.
  socks5: network.isLiquid ? null : settings.socks5,
);
