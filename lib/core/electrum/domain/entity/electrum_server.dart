import 'package:bb_mobile/core/electrum/domain/entity/electrum_server_provider.dart';

import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'electrum_server.freezed.dart';

enum ElectrumServerStatus { online, offline, unknown }

@freezed
sealed class ElectrumServer with _$ElectrumServer {
  const factory ElectrumServer({
    required String url,
    required Network network,
    String? socks5,
    @Default(20) int stopGap,
    @Default(5) int timeout,
    @Default(5) int retry,
    @Default(true) bool validateDomain,
    @Default(ElectrumServerStatus.unknown) ElectrumServerStatus status,
    @Default(false) bool isActive,
    @Default(0) int priority,
  }) = _ElectrumServer;
  const ElectrumServer._();
  ElectrumServerProvider get electrumServerProvider {
    if (url.contains('blockstream')) {
      return const ElectrumServerProvider.defaultProvider(
        defaultServerProvider: DefaultElectrumServerProvider.blockstream,
      );
    } else if (url.contains('bull')) {
      return const ElectrumServerProvider.defaultProvider();
    } else {
      return const ElectrumServerProvider.customProvider();
    }
  }
}
