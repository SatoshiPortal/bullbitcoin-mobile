import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import '../domain/exchange_call_result.dart';
import '../domain/exchange_failure.dart';

/// Classifies the answer of the write [call] into one [ExchangeWrite], and
/// maps a successful reply with [map].
///
/// The reply is mapped after the server accepted the write, so a mapping
/// failure, `Error`s included, is [WriteOutcomeUnknown], never a failure the
/// user could retry into a duplicate. [operation] names the call in logs.
Future<ExchangeWrite<T>> exchangeWrite<R, T>(
  String operation,
  Future<Result<R, bbx.BbxFailure>> Function() call,
  T Function(R reply) map,
) async {
  switch (await call()) {
    case Err(:final failure):
      final write = writeOf<T>(failure);
      log.warning(
        '$operation: ${_describeWrite(write)} (${_describe(failure)})',
      );
      return write;
    case Ok(value: final reply):
      try {
        return WriteDone(map(reply));
      } catch (e, st) {
        log.severe(
          message: '$operation succeeded but its reply could not be mapped',
          error: e.runtimeType.toString(),
          trace: st,
        );
        return WriteOutcomeUnknown('unmapped reply: ${e.runtimeType}');
      }
  }
}

/// The write result of a failed write.
///
/// `bbx_api` already turns a failure after a write may have reached the
/// server into [bbx.BbxOutcomeUnknownFailure]. A failure that only a read can
/// produce (a timeout after sending, a lost connection, an unreadable reply)
/// is also [WriteOutcomeUnknown] here, so a call that was not sent through
/// `BbxTransport.write` never re-arms a duplicate.
ExchangeWrite<T> writeOf<T>(bbx.BbxFailure failure) => switch (failure) {
  bbx.BbxOutcomeUnknownFailure(:final reason) => WriteOutcomeUnknown(reason),
  bbx.BbxHttpFailure(status: 401) => const WriteSessionRejected(),
  bbx.BbxHttpFailure(:final status) => WriteRefused(
    ExchangeRefusal(httpStatus: status),
  ),
  bbx.BbxRpcFailure(:final code, :final apiCode) ||
  bbx.BbxOrderLimitFailure(:final code, :final apiCode) ||
  bbx.BbxConfidentialSepaInactiveFailure(
    :final code,
    :final apiCode,
  ) => WriteRefused(ExchangeRefusal(rpcCode: code, apiCode: apiCode)),
  bbx.BbxMissingCredentialFailure() => const WriteNotSent(
    ExchangeNotSentReason.signedOut,
  ),
  bbx.BbxCredentialUnavailableFailure() => const WriteNotSent(
    ExchangeNotSentReason.credentialUnavailable,
  ),
  bbx.BbxTimeoutFailure(kind: bbx.BbxTimeoutKind.connect) ||
  bbx.BbxBadCertificateFailure() ||
  bbx.BbxRequestCancelledFailure() => const WriteNotSent(
    ExchangeNotSentReason.unreachable,
  ),
  bbx.BbxTimeoutFailure(:final kind) => WriteOutcomeUnknown(
    '${kind.name} timeout',
  ),
  bbx.BbxConnectionFailure() => const WriteOutcomeUnknown('connection lost'),
  bbx.BbxTransformTimeoutFailure() => const WriteOutcomeUnknown(
    'transform timeout',
  ),
  bbx.BbxTransportFailure() => const WriteOutcomeUnknown('transport failure'),
  bbx.BbxResponseFormatFailure(:final reason) => WriteOutcomeUnknown(reason),
};

/// The write result of a write that never ran because the exchange session
/// refused it first ([failure] comes from the session check around the call,
/// never from the server).
ExchangeWrite<T> writeNotRun<T>(ExchangeFailure failure) => switch (failure) {
  ExchangeNotAuthenticatedFailure() => const WriteNotSent(
    ExchangeNotSentReason.signedOut,
  ),
  ExchangeCredentialReadFailure() => const WriteNotSent(
    ExchangeNotSentReason.credentialUnavailable,
  ),
  ExchangeOperationStaleFailure() => const WriteNotSent(
    ExchangeNotSentReason.sessionChanged,
  ),
  ExchangeSessionRejectedFailure() => const WriteSessionRejected(),
  _ => const WriteNotSent(ExchangeNotSentReason.unreachable),
};

/// Classifies the answer of the read [call] into one [ExchangeRead], and
/// maps a reply with [map]. A `null` reply is [ReadMissing]; a reply that
/// can't be read or mapped is [ReadMalformed].
Future<ExchangeRead<T>> exchangeRead<R extends Object, T>(
  String operation,
  Future<Result<R?, bbx.BbxFailure>> Function() call,
  T Function(R reply) map,
) async {
  switch (await call()) {
    case Err(:final failure):
      log.warning('$operation failed: ${_describe(failure)}');
      return switch (_readFailure(failure)) {
        _Rejected(:final why) => ReadSessionRejected(why),
        _Unreachable(:final isNetwork) => ReadUnreachable(
          _describe(failure),
          isNetwork: isNetwork,
        ),
        _Malformed() => ReadMalformed(_describe(failure)),
      };
    case Ok(value: null):
      return const ReadMissing();
    case Ok(value: final R reply):
      try {
        return ReadGot(map(reply));
      } catch (e, st) {
        log.severe(
          message: '$operation reply could not be mapped',
          error: e.runtimeType.toString(),
          trace: st,
        );
        return ReadMalformed('unmapped reply: ${e.runtimeType}');
      }
  }
}

/// Classifies the answer of the list [call] for one page into one
/// [ExchangeList], and maps its items with [map]. A list that can't be read
/// is [ListUnreachable], never an empty page.
Future<ExchangeList<T>> exchangeList<R, T>(
  String operation,
  Future<Result<({List<R> items, int? next}), bbx.BbxFailure>> Function() call,
  T Function(R item) map,
) async {
  switch (await call()) {
    case Err(:final failure):
      log.warning('$operation failed: ${_describe(failure)}');
      return switch (_readFailure(failure)) {
        _Rejected(:final why) => ListSessionRejected(why),
        _Unreachable(:final isNetwork) => ListUnreachable(
          _describe(failure),
          isNetwork: isNetwork,
        ),
        _Malformed() => ListUnreachable(_describe(failure), isNetwork: false),
      };
    case Ok(value: final reply):
      try {
        return ListPage([
          for (final item in reply.items) map(item),
        ], next: reply.next);
      } catch (e, st) {
        log.severe(
          message: '$operation page could not be mapped',
          error: e.runtimeType.toString(),
          trace: st,
        );
        return ListUnreachable(
          'unmapped page: ${e.runtimeType}',
          isNetwork: false,
        );
      }
  }
}

sealed class _ReadFailure {
  const _ReadFailure();
}

final class _Rejected extends _ReadFailure {
  final ExchangeSessionRejection why;

  const _Rejected(this.why);
}

final class _Unreachable extends _ReadFailure {
  final bool isNetwork;

  const _Unreachable({required this.isNetwork});
}

final class _Malformed extends _ReadFailure {
  const _Malformed();
}

_ReadFailure _readFailure(bbx.BbxFailure failure) => switch (failure) {
  bbx.BbxMissingCredentialFailure() => const _Rejected(
    ExchangeSessionRejection.signedOut,
  ),
  bbx.BbxCredentialUnavailableFailure() => const _Rejected(
    ExchangeSessionRejection.credentialUnavailable,
  ),
  bbx.BbxHttpFailure(status: 401) => const _Rejected(
    ExchangeSessionRejection.server,
  ),
  bbx.BbxTimeoutFailure() ||
  bbx.BbxConnectionFailure() => const _Unreachable(isNetwork: true),
  bbx.BbxResponseFormatFailure() => const _Malformed(),
  bbx.BbxHttpFailure() ||
  bbx.BbxRpcFailure() ||
  bbx.BbxOrderLimitFailure() ||
  bbx.BbxConfidentialSepaInactiveFailure() ||
  bbx.BbxBadCertificateFailure() ||
  bbx.BbxRequestCancelledFailure() ||
  bbx.BbxTransformTimeoutFailure() ||
  bbx.BbxTransportFailure() ||
  bbx.BbxOutcomeUnknownFailure() => const _Unreachable(isNetwork: false),
};

String _describeWrite(ExchangeWrite<Object?> write) => switch (write) {
  WriteDone() => 'done',
  WriteRefused() => 'refused',
  WriteOutcomeUnknown() => 'outcome unknown',
  WriteNotSent(:final reason) => 'not sent (${reason.name})',
  WriteSessionRejected() => 'session rejected',
};

/// The failure's codes and kind only: a JSON-RPC message can quote the
/// request or account details.
String _describe(bbx.BbxFailure failure) => switch (failure) {
  bbx.BbxRpcFailure(:final code, :final apiCode) =>
    'BbxRpcFailure(code: $code, apiCode: $apiCode)',
  bbx.BbxOrderLimitFailure(:final code, :final apiCode) =>
    'BbxOrderLimitFailure(code: $code, apiCode: $apiCode)',
  bbx.BbxConfidentialSepaInactiveFailure(:final code, :final apiCode) =>
    'BbxConfidentialSepaInactiveFailure(code: $code, apiCode: $apiCode)',
  bbx.BbxMissingCredentialFailure() ||
  bbx.BbxCredentialUnavailableFailure() ||
  bbx.BbxHttpFailure() ||
  bbx.BbxTimeoutFailure() ||
  bbx.BbxConnectionFailure() ||
  bbx.BbxBadCertificateFailure() ||
  bbx.BbxRequestCancelledFailure() ||
  bbx.BbxTransformTimeoutFailure() ||
  bbx.BbxTransportFailure() ||
  bbx.BbxOutcomeUnknownFailure() ||
  bbx.BbxResponseFormatFailure() => failure.toString(),
};
