import 'dart:isolate';

import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:primitives/primitives.dart';

import '../../domain/ports/wallet_connection_port.dart';
import '../../domain/sync_failure.dart';

/// What a full scan of a wallet not yet imported finds: its confirmed
/// balance and its transaction count. The wallet lives in memory for the
/// scan only; nothing is written. Library function: no store is opened.
Future<Result<({BigInt confirmedSat, int transactions}), SyncFailure>>
prescanBitcoinWallet({
  required String externalDescriptor,
  required String internalDescriptor,
  required BitcoinNetwork network,
  required WalletConnection connection,
}) => Isolate.run(() {
  try {
    return Ok(
      _performDryScan(
        externalDescriptor,
        internalDescriptor,
        network,
        connection,
      ),
    );
  } on bdk.ElectrumException {
    return const Err(SyncConnectionFailure());
  } on bdk.CannotConnectException {
    return const Err(SyncConnectionFailure());
  } on Exception {
    return const Err(SyncInvalidCatalogFailure());
  }
});

({BigInt confirmedSat, int transactions}) _performDryScan(
  String externalDescriptor,
  String internalDescriptor,
  BitcoinNetwork network,
  WalletConnection connection,
) {
  final bdkNetwork = switch (network) {
    BitcoinNetwork.mainnet => bdk.Network.bitcoin,
    BitcoinNetwork.testnet => bdk.Network.testnet,
    BitcoinNetwork.regtest => bdk.Network.regtest,
    BitcoinNetwork.signet => throw const FormatException('signet'),
  };
  final kind = network == BitcoinNetwork.mainnet
      ? bdk.NetworkKind.main
      : bdk.NetworkKind.test;
  bdk.Descriptor? external;
  bdk.Descriptor? internal;
  try {
    external = bdk.Descriptor(
      descriptor: externalDescriptor,
      networkKind: kind,
    );
    internal = bdk.Descriptor(
      descriptor: internalDescriptor,
      networkKind: kind,
    );
    final persister = bdk.Persister.newInMemory();
    try {
      final wallet = bdk.Wallet(
        descriptor: external,
        changeDescriptor: internal,
        network: bdkNetwork,
        persister: persister,
        lookahead: 0,
      );
      try {
        final client = _client(connection);
        try {
          final builder = wallet.startFullScan();
          try {
            final request = builder.build();
            try {
              final update = client.fullScan(
                request: request,
                stopGap: connection.stopGap,
                batchSize: (connection.stopGap ~/ 4).clamp(50, 1000),
                fetchPrevTxouts: false,
              );
              try {
                wallet.applyUpdate(update: update);
                final balance = wallet.balance();
                return (
                  confirmedSat: BigInt.from(balance.confirmed.toSat()),
                  transactions: wallet.transactions().length,
                );
              } finally {
                update.dispose();
              }
            } finally {
              request.dispose();
            }
          } finally {
            builder.dispose();
          }
        } finally {
          client.dispose();
        }
      } finally {
        wallet.dispose();
      }
    } finally {
      persister.dispose();
    }
  } finally {
    internal?.dispose();
    external?.dispose();
  }
}

/// Retries once on rustls' CryptoProvider install race between isolates.
bdk.ElectrumClient _client(WalletConnection connection) {
  bdk.ElectrumClient build() => bdk.ElectrumClient(
    url: connection.url,
    socks5: connection.socks5?.isNotEmpty == true ? connection.socks5 : null,
    timeout: connection.timeout.inSeconds.clamp(0, 255),
    retry: connection.retry.clamp(0, 255),
    validateDomain: connection.validateDomain,
  );
  try {
    return build();
  } on bdk.CouldNotCreateConnectionElectrumException catch (error) {
    if (error.errorMessage.contains('Failed to install CryptoProvider')) {
      return build();
    }
    rethrow;
  }
}
