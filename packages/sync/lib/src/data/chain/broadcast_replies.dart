import 'dart:convert';

import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:rust_bindings/lwk.dart' as lwk;

import '../../domain/sync_failure.dart';

/// Reduces a native broadcast error, raised once the client is connected,
/// to a closed vocabulary; the server's text never leaves this function. Only
/// a server reply can be a cause: a connection lost during or after the send
/// is an unknown outcome, since the transaction may have been relayed. A
/// connection that could not be made before the send is classified by the
/// caller.
SyncFailure bitcoinBroadcastFailure(Object error) => switch (error) {
  bdk.ProtocolElectrumException(:final errorMessage) => _bitcoinReply(
    errorMessage,
  ),
  // BDK AllAttemptsErrored has discarded its causes in the native binding.
  _ => const SyncOutcomeUnknownFailure(),
};

/// The LWK counterpart of [bitcoinBroadcastFailure].
SyncFailure liquidBroadcastFailure(Object error) => switch (error) {
  lwk.LwkError(:final msg) => _liquidReply(msg),
  _ => const SyncOutcomeUnknownFailure(),
};

/// One verdict for every server tried: a single cause only when they all
/// agree, so a retry after an uncertain attempt never reads as a rejection.
SyncFailure combineBroadcastAttempts(List<SyncFailure> attempts) {
  if (attempts.isEmpty) return const SyncOutcomeUnknownFailure();
  final first = attempts.first;
  return attempts.every((attempt) => attempt.runtimeType == first.runtimeType)
      ? first
      : const SyncOutcomeUnknownFailure();
}

/// Recognizes the "unknown transaction" replies of the Electrum servers we
/// ship: electrs and esplora answer `missing transaction`, Fulcrum relays
/// bitcoind's `No such mempool or blockchain transaction`.
/// `No such mempool transaction. Use -txindex or provide a block hash`
/// remains unrecognized: it can mean a confirmed transaction is unavailable
/// without an index, so treating it as absent could permit a competing spend.
bool isUnknownTransactionReply(String message) {
  final normalized = message.toLowerCase();
  return normalized.contains('missing transaction') ||
      normalized.contains('no such mempool or blockchain transaction');
}

SyncFailure _bitcoinReply(String reply) {
  if (reply.length > 4096) return const SyncOutcomeUnknownFailure();
  try {
    final decoded = jsonDecode(reply);
    if (decoded is Map<String, dynamic>) {
      final code = decoded['code'];
      final message = decoded['message'];
      // bdk-dart 757d4e8 exposes Protocol's JSON value as a string. Some servers relay bitcoind -26 inside code 2 (observed on device 2026-11-09).
      // Accept only that exact envelope/prefix, never an arbitrary "-26" match.
      if (code is int &&
          (code == -26 ||
              (code == 2 &&
                  message is String &&
                  message.startsWith('sendrawtransaction RPC error -26: ')))) {
        return const SyncBroadcastRejectedFailure();
      }
      // Rebroadcasting a confirmed transaction relays bitcoind -27 in the same envelope (observed 2026-11-12):
      // {"code":2,"message":"sendrawtransaction RPC error -27: Transaction outputs already in utxo set"}.
      if (code is int &&
          (code == -27 ||
              (code == 2 &&
                  message is String &&
                  message.startsWith('sendrawtransaction RPC error -27: ')))) {
        return const SyncAlreadyInChainFailure();
      }
    }
  } on FormatException {
    // Unrecognized protocol payload; the original text must not escape.
  }
  return const SyncOutcomeUnknownFailure();
}

SyncFailure _liquidReply(String reply) {
  if (reply.length > 4096 || !reply.endsWith('))')) {
    return const SyncOutcomeUnknownFailure();
  }
  // bull_sdk f4ee00b -> lwk-dart f554c78 -> lwk_wollet 0.18.0 erases the native type into Rust Debug text (LwkError.msg).
  // These anchored outer variants are the entire allowlist, not a parser for arbitrary Rust text.
  // serde_json's ordered Object puts "code" first. Format changes, nested retries and unfamiliar envelopes deliberately degrade to an unknown outcome.
  if (reply.startsWith('ClientError(IOError(') ||
      reply.startsWith('ClientError(SharedIOError(') ||
      reply.startsWith('ClientError(CouldNotCreateConnection(')) {
    return const SyncConnectionFailure();
  }
  if (reply.startsWith('ClientError(Protocol(Object {"code": Number(-26),') ||
      reply == 'ClientError(Protocol(Object {"code": Number(-26)}))' ||
      reply.startsWith(
        'ClientError(Protocol(Object {"code": Number(2), "message": String("sendrawtransaction RPC error -26: ',
      )) {
    return const SyncBroadcastRejectedFailure();
  }
  return const SyncOutcomeUnknownFailure();
}
