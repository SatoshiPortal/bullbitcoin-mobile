import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/utils/descriptor_derivation.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_scanner.dart';

/// [PassphraseWalletScanner] over the wallet's existing BDK datasource and the
/// user's configured Electrum servers.
///
/// This is the one file in the feature that knows either of them exists: the
/// port keeps BDK and Electrum out of the passphrase domain and presentation
/// (spec 14, 20.7).
final class ElectrumPassphraseWalletScanner implements PassphraseWalletScanner {
  final BdkWalletDatasource _bdk;
  final ElectrumServersPort _servers;

  const ElectrumPassphraseWalletScanner(this._bdk, this._servers);

  @override
  Future<BigInt> scan({
    required String combinedPublicDescriptor,
    required Network network,
  }) async {
    try {
      final branches =
          DescriptorDerivation.splitCombinedPublicBitcoinDescriptor(
            combinedPublicDescriptor,
            network,
          );
      return await _servers.runWithFallback(
        network: ElectrumServerNetwork.fromEnvironment(
          isTestnet: network.isTestnet,
          isLiquid: false,
        ),
        operation: (server) => _bdk.dryScanDescriptors(
          externalDescriptor: branches.external,
          internalDescriptor: branches.internal,
          isTestnet: network.isTestnet,
          electrumServer: server,
        ),
      );
    } on Exception {
      // The original error is dropped rather than wrapped: every one of them
      // quotes the descriptor it failed on, and the descriptor identifies the
      // wallet to anyone reading a log.
      throw const PassphraseWalletScanException();
    }
  }
}
