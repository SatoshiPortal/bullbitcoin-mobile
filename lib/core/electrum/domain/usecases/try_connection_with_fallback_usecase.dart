import 'package:bb_mobile/core/electrum/data/repository/electrum_server_repository_impl.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server_provider.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class TryConnectionWithFallbackUsecase {
  final ElectrumServerRepository _electrumServerRepository;

  TryConnectionWithFallbackUsecase({
    required ElectrumServerRepository electrumServerRepository,
  }) : _electrumServerRepository = electrumServerRepository;

  /// Attempts to connect to servers in priority order until a successful connection is made
  /// Returns a list of servers with their updated status, and the index of the first successful server
  Future<(List<ElectrumServer>, int?)> execute({
    required List<ElectrumServer> servers,
    int? timeout,
  }) async {
    final List<ElectrumServer> updatedServers = [];
    int? firstSuccessIndex;

    final customServers =
        servers
            .where(
              (s) => s.electrumServerProvider is CustomElectrumServerProvider,
            )
            .toList();

    final serversToUse =
        customServers.isNotEmpty
            ? customServers
            : servers
                .where(
                  (s) =>
                      s.electrumServerProvider is! CustomElectrumServerProvider,
                )
                .toList();

    final sortedServers = List<ElectrumServer>.from(serversToUse)..sort((a, b) {
      final aIsCustom =
          a.electrumServerProvider is CustomElectrumServerProvider;
      final bIsCustom =
          b.electrumServerProvider is CustomElectrumServerProvider;

      if (!aIsCustom && !bIsCustom) {
        // If both are default servers, sort by provider (Bull Bitcoin priority 1, Blockstream priority 2)
        final aProvider = a.electrumServerProvider;
        final bProvider = b.electrumServerProvider;

        return aProvider.map(
          defaultProvider:
              (a) => bProvider.map(
                defaultProvider: (b) {
                  return (a.defaultServerProvider ==
                              DefaultElectrumServerProvider.bullBitcoin
                          ? 1
                          : 2)
                      .compareTo(
                        b.defaultServerProvider ==
                                DefaultElectrumServerProvider.bullBitcoin
                            ? 1
                            : 2,
                      );
                },
                customProvider: (_) => 0, // Should never happen as we filtered
              ),
          customProvider: (_) => 0, // Should never happen as we filtered
        );
      }
      // For custom servers, use their priority field
      return b.priority.compareTo(a.priority);
    });

    for (var i = 0; i < sortedServers.length; i++) {
      final server = sortedServers[i];
      final status = await _electrumServerRepository.checkServerConnectivity(
        url: server.url,
        timeout: timeout ?? server.timeout,
      );

      final updatedServer = server.copyWith(status: status);
      updatedServers.add(updatedServer);

      if (status == ElectrumServerStatus.online && firstSuccessIndex == null) {
        firstSuccessIndex = i;
        log.info('Successfully connected to server: ${server.url}');
      } else {
        log.warning('Failed to connect to server: ${server.url}');
      }
    }

    return (updatedServers, firstSuccessIndex);
  }
}
