import 'package:electrum/setup.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

/// The server answered the transaction lookup with a protocol error we do not
/// classify: neither a recognized "unknown transaction" reply nor a transport
/// failure. Electrum Personal Server and bitcoind without txindex word their
/// replies differently, so callers may fall back to a script-based sync.
class UnrecognizedElectrumReplyException implements Exception {
  final String reply;

  const UnrecognizedElectrumReplyException(this.reply);

  @override
  String toString() => 'UnrecognizedElectrumReplyException';
}

/// A lookup or broadcast sync could not complete; the category alone survives.
class BitcoinChainException implements Exception {
  final SyncFailure failure;

  const BitcoinChainException(this.failure);

  @override
  String toString() => 'BitcoinChainException(${failure.logCode})';
}

/// One-server chain access for Payjoin, which runs its own fallback. Sync
/// does the work; this only adapts the connection and the exception contract.
class BdkBitcoinBlockchainDatasource {
  const BdkBitcoinBlockchainDatasource();

  /// Throws [FormatException] when [finalizedPsbt] is not a PSBT.
  Future<String> broadcastPsbt(
    String finalizedPsbt, {
    required ElectrumConnection connection,
  }) => broadcastTransaction(
    decodeBitcoinPsbt(finalizedPsbt).bytes,
    connection: connection,
  );

  Future<String> broadcastTransaction(
    List<int> transaction, {
    required ElectrumConnection connection,
  }) async => switch (await broadcastBitcoinTransactionTo(
    _route(connection),
    transaction,
  )) {
    Ok(:final value) => value,
    Err(:final failure) => throw BitcoinChainException(failure),
  };

  /// Whether the server knows [txId], in its mempool or in a block.
  ///
  /// Answers `false` only on the server's explicit "unknown transaction"
  /// reply; any other failure throws, so an unreachable server is never
  /// mistaken for an absent transaction.
  Future<bool> isTransactionKnown(
    String txId, {
    required ElectrumConnection connection,
  }) async => switch (await bitcoinTransactionKnown(txId, _route(connection))) {
    Ok(:final value) => value,
    Err(failure: SyncUnrecognizedReplyFailure(:final logCode)) =>
      throw UnrecognizedElectrumReplyException(logCode),
    Err(:final failure) => throw BitcoinChainException(failure),
  };

  static WalletConnection _route(ElectrumConnection connection) =>
      WalletConnection(
        url: connection.url,
        timeout: Duration(seconds: connection.effectiveTimeout),
        retry: connection.retry,
        stopGap: connection.stopGap,
        validateDomain: connection.validateDomain,
        socks5: connection.socks5,
      );
}
