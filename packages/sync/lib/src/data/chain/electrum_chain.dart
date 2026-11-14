import 'dart:isolate';
import 'dart:typed_data';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';

import '../../domain/ports/wallet_connection_port.dart';
import '../../domain/sync_failure.dart';
import '../codec/bitcoin_codec.dart';
import 'broadcast_replies.dart';

/// Sends a signed Bitcoin transaction through the servers the owner's
/// [connections] port selects, and returns its locally computed txid.
///
/// Each failed server is followed by the next one. The failure names a single
/// cause only when every server agreed on it; otherwise the outcome is
/// [SyncOutcomeUnknownFailure], because a transaction an earlier server may
/// have relayed must never read as rejected. Nothing is retried after the
/// port's servers are exhausted.
Future<Result<String, SyncFailure>> broadcastBitcoinTransaction(
  List<int> transaction, {
  required BitcoinNetwork network,
  required WalletConnectionPort connections,
}) async {
  final String txid;
  switch (decodeBitcoinTransaction(transaction)) {
    case Ok(:final value):
      txid = value.txid;
    case Err(:final failure):
      return Err(failure);
  }
  final bytes = Uint8List.fromList(transaction);
  return _broadcast(
    network: network,
    connections: connections,
    send: (connection) async {
      try {
        final client = _connect(connection);
        try {
          final native = bdk.Transaction(transactionBytes: bytes);
          try {
            client.transactionBroadcast(tx: native).dispose();
          } finally {
            native.dispose();
          }
        } finally {
          client.dispose();
        }
        return Ok(txid);
      } on Exception catch (error) {
        return Err(bitcoinBroadcastFailure(error));
      }
    },
  );
}

/// Sends a signed PSET through the servers [connections] selects. Liquid has
/// no spend gate: nothing here protects a concurrent spend of its inputs.
///
/// ⚠️ LWK connects directly, without the SOCKS route.
Future<Result<String, SyncFailure>> broadcastLiquidTransaction(
  String signedPset, {
  required LiquidNetwork network,
  required WalletConnectionPort connections,
}) => _broadcast(
  network: network,
  connections: connections,
  send: (connection) async {
    try {
      return Ok(
        await lwk.Blockchain.broadcastSignedPset(
          network: switch (network) {
            LiquidNetwork.mainnet => lwk.LiquidNetwork.mainnet,
            LiquidNetwork.testnet => lwk.LiquidNetwork.testnet,
            LiquidNetwork.regtest => lwk.LiquidNetwork.regtest,
          },
          electrumUrl: connection.url,
          signedPset: signedPset,
        ),
      );
    } on Exception catch (error) {
      return Err(liquidBroadcastFailure(error));
    }
  },
);

/// Whether the server behind [connection] knows [txid], in its mempool or in
/// a block, with one `blockchain.transaction.get` round trip.
///
/// `false` only on the server's explicit "unknown transaction" reply. A reply
/// whose bytes do not hash to [txid] is [SyncInvalidTransactionFailure]; a
/// server error we do not classify is [SyncUnrecognizedReplyFailure], so an
/// unreachable or unfamiliar server is never mistaken for an absence.
Future<Result<bool, SyncFailure>> bitcoinTransactionKnown(
  String txid,
  WalletConnection connection,
) => Isolate.run<Result<bool, SyncFailure>>(() {
  try {
    final client = _connect(connection);
    try {
      final id = bdk.Txid.fromString(hex: txid);
      final Uint8List raw;
      try {
        raw = client.transactionGetRaw(txid: id);
      } finally {
        id.dispose();
      }
      // The reply settles payjoin sessions, so "no error" is not enough: the
      // bytes must deserialize and hash to the requested id.
      return switch (decodeBitcoinTransaction(raw)) {
        Ok(:final value) when value.txid == txid.toLowerCase() => const Ok(
          true,
        ),
        _ => const Err(SyncInvalidTransactionFailure()),
      };
    } finally {
      client.dispose();
    }
  } on bdk.ProtocolElectrumException catch (error) {
    return isUnknownTransactionReply(error.errorMessage)
        ? const Ok(false)
        : const Err(SyncUnrecognizedReplyFailure());
  } on Exception {
    return const Err(SyncConnectionFailure());
  }
});

/// Proves the server behind [connection] speaks Electrum for Bitcoin: a
/// header subscription, then [knownTxid] fetched when one is given.
Future<Result<void, SyncFailure>> probeBitcoinServer(
  WalletConnection connection, {
  String? knownTxid,
}) => Isolate.run<Result<void, SyncFailure>>(() {
  try {
    final client = _connect(connection);
    try {
      client.blockHeadersSubscribe();
      if (knownTxid != null) {
        final id = bdk.Txid.fromString(hex: knownTxid);
        try {
          client.fetchTx(txid: id).dispose();
        } finally {
          id.dispose();
        }
      }
      return const Ok(null);
    } finally {
      client.dispose();
    }
  } on Exception {
    return const Err(SyncConnectionFailure());
  }
});

/// The server's `blockchain.estimatefee` answer for each confirmation target,
/// in BTC per kilobyte as Electrum reports it (`-1` when it has none).
Future<Result<List<double>, SyncFailure>> estimateBitcoinFees(
  WalletConnection connection, {
  required List<int> targets,
}) => Isolate.run<Result<List<double>, SyncFailure>>(() {
  try {
    final client = _connect(connection);
    try {
      return Ok([
        for (final target in targets) client.estimateFee(number: target),
      ]);
    } finally {
      client.dispose();
    }
  } on Exception {
    return const Err(SyncConnectionFailure());
  }
});

Future<Result<String, SyncFailure>> _broadcast({
  required Network network,
  required WalletConnectionPort connections,
  required Future<Result<String, SyncFailure>> Function(WalletConnection) send,
}) async {
  final attempts = <SyncFailure>[];
  final result = await connections.run(
    network: network,
    operation: (connection) async {
      final result = await send(connection);
      if (result case Err(:final failure)) attempts.add(failure);
      return result;
    },
    mayRetry: (_) => true,
  );
  return switch (result) {
    Ok() => result,
    Err() when attempts.isNotEmpty => Err(combineBroadcastAttempts(attempts)),
    Err() => result,
  };
}

bdk.ElectrumClient _connect(WalletConnection connection) {
  bdk.ElectrumClient build() => bdk.ElectrumClient(
    url: connection.url.contains('://')
        ? connection.url
        : 'ssl://${connection.url}',
    socks5: connection.socks5?.isNotEmpty == true ? connection.socks5 : null,
    // electrum-client caps timeout/retry at u8 (255s, 255 retries).
    timeout: connection.timeout.inSeconds.clamp(0, 255),
    retry: connection.retry.clamp(0, 255),
    validateDomain: connection.validateDomain,
  );
  try {
    return build();
  } on bdk.CouldNotCreateConnectionElectrumException catch (error) {
    if (!error.errorMessage.contains('Failed to install CryptoProvider')) {
      rethrow;
    }
    // Concurrent BDK isolates can race while installing rustls' global
    // provider. The winner has installed it by the time this retry runs.
    return build();
  }
}
