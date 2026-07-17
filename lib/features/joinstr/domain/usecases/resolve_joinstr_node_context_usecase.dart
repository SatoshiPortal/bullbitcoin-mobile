import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/resolve_joinstr_proxy_usecase.dart';

/// Everything a joinstr call needs from the wallet except the output address:
/// the mnemonic joinstr's hot signer derives from, an electrum server to scan
/// coins and verify peers against, and the Tor proxy to route through. Shared
/// by coin listing and by creating/joining a pool.
class JoinstrNodeContext {
  final String mnemonic;
  final String electrumUrl;
  final String proxy;

  const JoinstrNodeContext({
    required this.mnemonic,
    required this.electrumUrl,
    required this.proxy,
  });
}

class ResolveJoinstrNodeContextUsecase {
  final SeedRepository _seedRepository;
  final ElectrumServerRepository _electrumServerRepository;
  final ResolveJoinstrProxyUsecase _resolveProxy;

  ResolveJoinstrNodeContextUsecase({
    required this._seedRepository,
    required this._electrumServerRepository,
    required ResolveJoinstrProxyUsecase resolveProxyUsecase,
  }) : _resolveProxy = resolveProxyUsecase;

  Future<JoinstrNodeContext> execute({required Wallet wallet}) async {
    Joinstr.assertWalletSupported(wallet);

    // Resolve Tor before anything touches the network: a round that cannot go
    // over Tor must not proceed at all.
    final proxy = await _resolveProxy.execute();

    final seed = await _seedRepository.get(wallet.masterFingerprint);
    if (seed is! MnemonicSeed) {
      throw JoinstrException(JoinstrIssue.watchOnlyWallet);
    }

    final servers = await _electrumServerRepository.fetchActiveServers(
      network: ElectrumServerNetwork.fromEnvironment(
        isTestnet: wallet.isTestnet,
        isLiquid: false,
      ),
    );
    final electrumUrl = servers.fold(
      (value) => value.isEmpty
          ? throw JoinstrException(JoinstrIssue.invalidElectrumUrl)
          : value.first.url,
      (failure) => throw JoinstrException(
        JoinstrIssue.invalidElectrumUrl,
        detail: failure.logMessage,
      ),
    );

    return JoinstrNodeContext(
      mnemonic: seed.mnemonicWords.join(' '),
      electrumUrl: electrumUrl,
      proxy: proxy,
    );
  }
}
