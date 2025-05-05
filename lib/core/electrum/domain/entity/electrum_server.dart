import 'package:bb_mobile/core/electrum/domain/entity/electrum_server_provider.dart';
import 'package:bb_mobile/core/utils/constants.dart';
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
    required ElectrumServerProvider electrumServerProvider,
    @Default(20) int stopGap,
    @Default(5) int timeout,
    @Default(5) int retry,
    @Default(true) bool validateDomain,
    @Default(ElectrumServerStatus.unknown) ElectrumServerStatus status,
    @Default(false) bool isActive,
    @Default(0) int priority,
  }) = _ElectrumServer;

  // Default constructor for standard providers
  factory ElectrumServer.defaultServer({
    required DefaultElectrumServerProvider provider,
    required Network network,
    ElectrumServerStatus status = ElectrumServerStatus.unknown,
    int stopGap = 20,
    int timeout = 5,
    int retry = 5,
    bool validateDomain = true,
    int? priority,
  }) => ElectrumServer(
    url:
        provider == DefaultElectrumServerProvider.bullBitcoin
            ? ApiServiceConstants.bbElectrumUrl
            : ApiServiceConstants.publicElectrumUrl,
    electrumServerProvider: ElectrumServerProvider.defaultProvider(
      defaultServerProvider: provider,
    ),
    network: network,
    stopGap: stopGap,
    timeout: timeout,
    retry: retry,
    validateDomain: validateDomain,
    status: status,
    priority:
        priority ??
        (provider == DefaultElectrumServerProvider.bullBitcoin ? 1 : 2),
  );

  // Custom constructor for custom server with isActive flag
  factory ElectrumServer.customServer({
    String url = '',
    required Network network,
    String? socks5,
    ElectrumServerStatus status = ElectrumServerStatus.unknown,
    int stopGap = 20,
    int timeout = 5,
    int retry = 5,
    bool validateDomain = true,
    bool isActive = true,
  }) => ElectrumServer(
    url: url,
    socks5: socks5,
    network: network,
    stopGap: stopGap,
    timeout: timeout,
    retry: retry,
    validateDomain: validateDomain,
    status: status,
    isActive: isActive,
    electrumServerProvider: const ElectrumServerProvider.customProvider(),
  );
}
