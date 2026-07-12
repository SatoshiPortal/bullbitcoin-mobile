import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';

class JoinstrPeerContext {
  final String mnemonic;
  final String electrumUrl;
  final String outputAddress;

  const JoinstrPeerContext({
    required this.mnemonic,
    required this.electrumUrl,
    required this.outputAddress,
  });
}

/// Gathers the three things every joinstr round needs from the wallet: the
/// mnemonic joinstr's hot signer derives from, an electrum server to verify
/// peers against, and a fresh address to receive the denominated output.
class ResolveJoinstrPeerContextUsecase {
  final SeedRepository _seedRepository;
  final ElectrumServerRepository _electrumServerRepository;
  final GetReceiveAddressUsecase _getReceiveAddressUsecase;

  ResolveJoinstrPeerContextUsecase({
    required this._seedRepository,
    required this._electrumServerRepository,
    required this._getReceiveAddressUsecase,
  });

  Future<JoinstrPeerContext> execute({required Wallet wallet}) async {
    Joinstr.assertWalletSupported(wallet);

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

    // A fresh address each round: joinstr's own address-reuse check is gated on
    // an electrum client the peer flow never supplies, so it never runs.
    final address = await _getReceiveAddressUsecase.execute(
      walletId: wallet.id,
      generateNew: true,
    );

    return JoinstrPeerContext(
      mnemonic: seed.mnemonicWords.join(' '),
      electrumUrl: electrumUrl,
      outputAddress: address.address,
    );
  }
}
