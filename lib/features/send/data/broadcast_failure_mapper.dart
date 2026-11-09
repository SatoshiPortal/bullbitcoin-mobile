import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/features/send/domain/broadcast_failure.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_sdk/lwk.dart' as lwk;

/// Reduce SDK/fallback causes to a closed vocabulary; never retain or log text.
/// Mixed attempts do not establish a single cause (or prove non-broadcast).
BroadcastFailureCategory mapBroadcastFailure(Object error) {
  var remaining = 64;
  BroadcastFailureCategory classify(Object cause, int depth) {
    if (depth > 4 || remaining-- <= 0) {
      return BroadcastFailureCategory.unexpected;
    }
    if (cause is CategorizedBroadcastException) return cause.category;
    if (cause is AllElectrumServersFailedException) {
      if (cause.attempts.isEmpty || cause.attempts.length > remaining) {
        return BroadcastFailureCategory.unexpected;
      }
      BroadcastFailureCategory? category;
      for (final attempt in cause.attempts) {
        final next = classify(attempt.error, depth + 1);
        if (category != null && category != next) {
          return BroadcastFailureCategory.unexpected;
        }
        category = next;
      }
      return category ?? BroadcastFailureCategory.unexpected;
    }
    if (cause is SocketException ||
        cause is TimeoutException ||
        cause is bdk.IoExceptionElectrumException ||
        cause is bdk.SharedIoExceptionElectrumException ||
        cause is bdk.CouldNotCreateConnectionElectrumException ||
        cause is OnionServerWithoutTorException ||
        cause is ClearnetServerWithoutConfiguredTorException) {
      return BroadcastFailureCategory.connection;
    }
    if (cause is bdk.ProtocolElectrumException) {
      return _bitcoinReply(cause.errorMessage);
    }
    if (cause is lwk.LwkError) return _liquidReply(cause.msg);
    // BDK AllAttemptsErrored has discarded its causes in the native binding.
    // Generic exceptions and programmer errors are never classified by text.
    return BroadcastFailureCategory.unexpected;
  }

  return classify(error, 0);
}

BroadcastFailureCategory _bitcoinReply(String reply) {
  if (reply.length > 4096) return BroadcastFailureCategory.unexpected;
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
        return BroadcastFailureCategory.rejected;
      }
    }
  } on FormatException {
    // Unrecognized protocol payload; the original text must not escape.
  }
  return BroadcastFailureCategory.unexpected;
}

BroadcastFailureCategory _liquidReply(String reply) {
  if (reply.length > 4096 || !reply.endsWith('))')) {
    return BroadcastFailureCategory.unexpected;
  }
  // bull_sdk f4ee00b -> lwk-dart f554c78 -> lwk_wollet 0.18.0 erases the native type into Rust Debug text (LwkError.msg).
  // These anchored outer variants are the entire allowlist, not a parser for arbitrary Rust text.
  // serde_json's ordered Object puts "code" first. Format changes, nested retries and unfamiliar envelopes deliberately degrade to unexpected.
  if (reply.startsWith('ClientError(IOError(') ||
      reply.startsWith('ClientError(SharedIOError(') ||
      reply.startsWith('ClientError(CouldNotCreateConnection(')) {
    return BroadcastFailureCategory.connection;
  }
  if (reply.startsWith('ClientError(Protocol(Object {"code": Number(-26),') ||
      reply == 'ClientError(Protocol(Object {"code": Number(-26)}))' ||
      reply.startsWith(
        'ClientError(Protocol(Object {"code": Number(2), "message": String("sendrawtransaction RPC error -26: ',
      )) {
    return BroadcastFailureCategory.rejected;
  }
  return BroadcastFailureCategory.unexpected;
}
