import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import '../domain/exchange_page.dart';
import '../domain/exchange_failure.dart';

/// Classifies the answer of the write [call] into one write result, and
/// maps a successful reply with [map].
///
/// The reply is mapped after the server accepted the write, so a mapping
/// failure, `Error`s included, is [ExchangeWriteOutcomeUnknownFailure], never a failure the
/// user could retry into a duplicate. [operation] names the call in logs.
Future<Result<T, ExchangeWriteFailure>> exchangeWrite<R, T>(
  String operation,
  Future<Result<R, bbx.BbxFailure>> Function() call,
  T Function(R reply) map,
) async {
  switch (await call()) {
    case Err(:final failure):
      final write = writeOf<T>(failure);
      log.warning('$operation: ${_describeWrite(write)} ($failure)');
      return write;
    case Ok(value: final reply):
      try {
        return Ok(map(reply));
      } catch (e, st) {
        log.severe(
          message: '$operation succeeded but its reply could not be mapped',
          error: e.runtimeType.toString(),
          trace: st,
        );
        return Err(
          ExchangeWriteOutcomeUnknownFailure(
            'unmapped reply: ${e.runtimeType}',
          ),
        );
      }
  }
}

/// The write result of a failed write.
///
/// `bbx_api` already turns a failure after a write may have reached the
/// server into [bbx.BbxOutcomeUnknownFailure]. A failure that only a read can
/// produce (a timeout after sending, a lost connection, an unreadable reply)
/// is also [ExchangeWriteOutcomeUnknownFailure] here, so a call that was not sent through
/// `BbxTransport.write` never re-arms a duplicate.
Result<T, ExchangeWriteFailure> writeOf<T>(
  bbx.BbxFailure failure,
) => switch (failure) {
  bbx.BbxOutcomeUnknownFailure(:final reason) => Err(
    ExchangeWriteOutcomeUnknownFailure(reason),
  ),
  bbx.BbxHttpFailure(status: 401) => const Err(
    ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
  ),
  bbx.BbxHttpFailure(:final status) => Err(
    ExchangeWriteRefusedFailure(ExchangeRefusal(httpStatus: status)),
  ),
  bbx.BbxRpcFailure(:final code, :final apiCode, :final fieldErrors) => Err(
    ExchangeWriteRefusedFailure(
      ExchangeRefusal(
        rpcCode: code,
        apiCode: apiCode,
        fieldErrors: fieldErrors,
      ),
    ),
  ),
  bbx.BbxOrderLimitFailure(
    :final code,
    :final apiCode,
    :final bound,
    :final amount,
    :final currency,
  ) =>
    Err(
      ExchangeWriteRefusedFailure(
        ExchangeRefusal(
          rpcCode: code,
          apiCode: apiCode,
          orderLimit: ExchangeOrderLimit(
            switch (bound) {
              bbx.BbxOrderLimitBound.minimum =>
                ExchangeOrderAmountBound.minimum,
              bbx.BbxOrderLimitBound.maximum =>
                ExchangeOrderAmountBound.maximum,
            },
            amount,
            currency,
          ),
        ),
      ),
    ),
  bbx.BbxConfidentialSepaInactiveFailure(:final code, :final apiCode) => Err(
    ExchangeWriteRefusedFailure(
      ExchangeRefusal(rpcCode: code, apiCode: apiCode, payeeInactive: true),
    ),
  ),
  bbx.BbxMissingCredentialFailure() => const Err(
    ExchangeWriteNotSentFailure(ExchangeNotSentReason.signedOut),
  ),
  bbx.BbxCredentialUnavailableFailure() => const Err(
    ExchangeWriteNotSentFailure(ExchangeNotSentReason.credentialUnavailable),
  ),
  bbx.BbxTimeoutFailure(kind: bbx.BbxTimeoutKind.connect) ||
  bbx.BbxBadCertificateFailure() ||
  bbx.BbxRequestCancelledFailure() => const Err(
    ExchangeWriteNotSentFailure(ExchangeNotSentReason.unreachable),
  ),
  bbx.BbxTimeoutFailure(:final kind) => Err(
    ExchangeWriteOutcomeUnknownFailure('${kind.name} timeout'),
  ),
  bbx.BbxConnectionFailure() => const Err(
    ExchangeWriteOutcomeUnknownFailure('connection lost'),
  ),
  bbx.BbxTransformTimeoutFailure() => const Err(
    ExchangeWriteOutcomeUnknownFailure('transform timeout'),
  ),
  bbx.BbxTransportFailure() => const Err(
    ExchangeWriteOutcomeUnknownFailure('transport failure'),
  ),
  bbx.BbxResponseFormatFailure(:final reason) => Err(
    ExchangeWriteOutcomeUnknownFailure(reason),
  ),
};

/// The write result of a write that never ran because the exchange session
/// refused it first ([failure] comes from the session check around the call,
/// never from the server).
Result<T, ExchangeWriteFailure> writeNotRun<T>(ExchangeFailure failure) =>
    switch (failure) {
      ExchangeNotAuthenticatedFailure() => const Err(
        ExchangeWriteNotSentFailure(ExchangeNotSentReason.signedOut),
      ),
      ExchangeCredentialReadFailure() => const Err(
        ExchangeWriteNotSentFailure(
          ExchangeNotSentReason.credentialUnavailable,
        ),
      ),
      ExchangeOperationStaleFailure() => const Err(
        ExchangeWriteNotSentFailure(ExchangeNotSentReason.sessionChanged),
      ),
      ExchangeSessionRejectedFailure() => const Err(
        ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
      ),
      _ => const Err(
        ExchangeWriteNotSentFailure(ExchangeNotSentReason.unreachable),
      ),
    };

/// The read result of a read that ended in [failure] before or around the
/// call (the session checks, or a repository that still answers with
/// [ExchangeFailure]): never a value, never an empty one.
Result<T, ExchangeReadFailure> readNotRun<T>(ExchangeFailure failure) =>
    switch (failure) {
      ExchangeNotAuthenticatedFailure() => const Err(
        ExchangeSessionRejectedFailure(ExchangeSessionRejection.signedOut),
      ),
      ExchangeCredentialReadFailure() ||
      ExchangeApiKeyStorageFailure() => const Err(
        ExchangeSessionRejectedFailure(
          ExchangeSessionRejection.credentialUnavailable,
        ),
      ),
      ExchangeSessionRejectedFailure() => const Err(
        ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
      ),
      ExchangeOperationStaleFailure() => const Err(
        ExchangeSessionRejectedFailure(ExchangeSessionRejection.sessionChanged),
      ),
      ExchangeNetworkFailure() => Err(
        ExchangeUnreachableFailure(
          failure.runtimeType.toString(),
          isNetwork: true,
        ),
      ),
      _ => Err(
        ExchangeUnreachableFailure(
          failure.runtimeType.toString(),
          isNetwork: false,
        ),
      ),
    };

/// Classifies the answer of the read [call] into one read result, and
/// maps a reply with [map]. A `null` reply is [ExchangeMissingFailure]; a reply that
/// can't be read or mapped is [ExchangeMalformedFailure].
Future<Result<T, ExchangeReadFailure>> exchangeRead<R extends Object, T>(
  String operation,
  Future<Result<R?, bbx.BbxFailure>> Function() call,
  T Function(R reply) map,
) async {
  switch (await call()) {
    case Err(:final failure):
      log.warning('$operation failed: $failure');
      return switch (_readFailure(failure)) {
        _Rejected(:final why) => Err(ExchangeSessionRejectedFailure(why)),
        _Unreachable(:final isNetwork) => Err(
          ExchangeUnreachableFailure('$failure', isNetwork: isNetwork),
        ),
        _Malformed() => Err(ExchangeMalformedFailure('$failure')),
      };
    case Ok(value: null):
      return const Err(ExchangeMissingFailure());
    case Ok(value: final R reply):
      try {
        return Ok(map(reply));
      } catch (e, st) {
        log.severe(
          message: '$operation reply could not be mapped',
          error: e.runtimeType.toString(),
          trace: st,
        );
        return Err(
          ExchangeMalformedFailure('unmapped reply: ${e.runtimeType}'),
        );
      }
  }
}

/// Classifies the answer of the list [call] for one page into one
/// [ExchangePage] or [ExchangeListFailure], and maps its items with [map]. A
/// list that can't be read is [ExchangeUnreachableFailure], never an empty
/// page.
Future<Result<ExchangePage<T>, ExchangeListFailure>> exchangeList<R, T>(
  String operation,
  Future<Result<({List<R> items, int? next}), bbx.BbxFailure>> Function() call,
  T Function(R item) map,
) async {
  switch (await call()) {
    case Err(:final failure):
      log.warning('$operation failed: $failure');
      return switch (_readFailure(failure)) {
        _Rejected(:final why) => Err(ExchangeSessionRejectedFailure(why)),
        _Unreachable(:final isNetwork) => Err(
          ExchangeUnreachableFailure('$failure', isNetwork: isNetwork),
        ),
        _Malformed() => Err(
          ExchangeUnreachableFailure('$failure', isNetwork: false),
        ),
      };
    case Ok(value: final reply):
      try {
        return Ok(
          ExchangePage([
            for (final item in reply.items) map(item),
          ], next: reply.next),
        );
      } catch (e, st) {
        log.severe(
          message: '$operation page could not be mapped',
          error: e.runtimeType.toString(),
          trace: st,
        );
        return Err(
          ExchangeUnreachableFailure(
            'unmapped page: ${e.runtimeType}',
            isNetwork: false,
          ),
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

String _describeWrite(Result<Object?, ExchangeWriteFailure> write) =>
    switch (write) {
      Ok() => 'done',
      Err(failure: ExchangeWriteRefusedFailure()) => 'refused',
      Err(failure: ExchangeWriteOutcomeUnknownFailure()) => 'outcome unknown',
      Err(failure: ExchangeWriteNotSentFailure(:final reason)) =>
        'not sent (${reason.name})',
      Err(failure: ExchangeSessionRejectedFailure()) => 'session rejected',
    };
