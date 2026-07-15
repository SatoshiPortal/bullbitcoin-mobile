import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/joinstr/data/joinstr_store.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/resolve_joinstr_proxy_usecase.dart';

class JoinstrPeerContext {
  final String mnemonic;
  final String electrumUrl;
  final String outputAddress;

  /// SOCKS5 proxy (local Tor) every relay and electrum connection is routed
  /// through for this round.
  final String proxy;

  const JoinstrPeerContext({
    required this.mnemonic,
    required this.electrumUrl,
    required this.outputAddress,
    required this.proxy,
  });
}

/// Gathers the three things every joinstr round needs from the wallet: the
/// mnemonic joinstr's hot signer derives from, an electrum server to verify
/// peers against, and a fresh address to receive the denominated output.
class ResolveJoinstrPeerContextUsecase {
  final SeedRepository _seedRepository;
  final ElectrumServerRepository _electrumServerRepository;
  final GetReceiveAddressUsecase _getReceiveAddressUsecase;
  final ResolveJoinstrProxyUsecase _resolveProxy;
  final JoinstrStore _store;

  ResolveJoinstrPeerContextUsecase({
    required this._seedRepository,
    required this._electrumServerRepository,
    required this._getReceiveAddressUsecase,
    required ResolveJoinstrProxyUsecase resolveProxyUsecase,
    required this._store,
  }) : _resolveProxy = resolveProxyUsecase;

  Future<JoinstrPeerContext> execute({required Wallet wallet}) async {
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

    // Reserve one fresh address for the round and reuse it across retries.
    // joinstr's own address-reuse check never runs here (it is gated on an
    // electrum client the peer flow does not supply), so a fresh address still
    // matters; but generating a new one on every attempt would walk the receive
    // chain toward the gap limit with addresses that never see funds. The
    // reservation is cleared on a successful broadcast (see the initiate/join
    // usecases), so each completed coinjoin gets a distinct address and a failed
    // round's reserved-but-unused address is reused rather than abandoned.
    var address = await _store.getReservedAddress();
    if (address == null) {
      final generated = await _getReceiveAddressUsecase.execute(
        walletId: wallet.id,
        generateNew: true,
      );
      address = generated.address;
      await _store.saveReservedAddress(address);
    }

    return JoinstrPeerContext(
      mnemonic: seed.mnemonicWords.join(' '),
      electrumUrl: electrumUrl,
      outputAddress: address,
      proxy: proxy,
    );
  }
}
