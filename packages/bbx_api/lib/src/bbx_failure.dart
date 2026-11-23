import 'package:primitives/primitives.dart';

/// A failed Bull Bitcoin API call, as a value.
///
/// Every public operation returns [Result] of its own type and one of these
/// variants. A failure never carries a request or a response payload; a
/// [BbxRpcFailure] keeps the server's text only in [BbxRpcFailure.message],
/// which [Object.toString] leaves out.
///
/// [requestId] is the server's identifier for the refused request, the one
/// value that lets the backend trace it. It is null when the server sent none
/// or the request never reached it.
sealed class BbxFailure extends Failure {
  /// Where the failed operation originated, for compatibility boundaries that
  /// translate this value back into a thrown exception. Never part of
  /// [toString], and never a transport exception or a payload.
  final StackTrace? origin;

  const BbxFailure([this.origin]);

  String? get requestId => null;

  /// ` requestId=<id>` to append to a diagnostic line, or nothing when the
  /// server sent no identifier.
  String get requestIdLabel {
    final id = requestId;
    return id == null ? '' : ' requestId=$id';
  }
}

/// Written `requestId=` on purpose: the log sanitizer keeps a token with
/// that label and redacts it under any other spelling.
String _requestIdSuffix(String? requestId) =>
    requestId == null ? '' : ', requestId=$requestId';

/// The user is signed out: the credential read returned no key.
///
/// The request was not sent.
final class BbxMissingCredentialFailure extends BbxFailure {
  const BbxMissingCredentialFailure();
}

/// The stored credential could not be read: the credential read failed.
///
/// The request was not sent.
final class BbxCredentialUnavailableFailure extends BbxFailure {
  const BbxCredentialUnavailableFailure();
}

/// The server answered with a status other than 200. [status] is null when
/// the transport reported a bad response without one.
final class BbxHttpFailure extends BbxFailure {
  final int? status;

  const BbxHttpFailure(this.status, {StackTrace? origin}) : super(origin);

  @override
  String toString() => 'BbxHttpFailure(status: $status)';
}

/// The server returned a JSON-RPC error.
///
/// [code] is the JSON-RPC code. [message] is the server's text, which can
/// quote account data, so [toString] leaves it out. [apiCode] is the error's
/// `data.apiError.code`, kept only when it is an `ERR_` code so that it never
/// carries account details.
final class BbxRpcFailure extends BbxFailure {
  final int? code;
  final String? message;
  final String? apiCode;
  @override
  final String? requestId;

  const BbxRpcFailure({
    this.code,
    this.message,
    this.apiCode,
    this.requestId,
    StackTrace? origin,
  }) : super(origin);

  @override
  String toString() =>
      'BbxRpcFailure(code: $code, apiCode: $apiCode'
      '${_requestIdSuffix(requestId)})';
}

/// The bound of an order limit that an amount crossed.
enum BbxOrderLimitBound { minimum, maximum }

/// The server refused an order because its amount is outside a limit.
///
/// When several payment options were refused against the same bound and
/// currency, [amount] is the lowest minimum or the highest maximum: the
/// amount that makes at least one of them possible. The server's message is
/// dropped: it repeats the account's own numbers.
final class BbxOrderLimitFailure extends BbxFailure {
  final BbxOrderLimitBound bound;
  final double amount;
  final String currency;
  final int? code;
  final String? apiCode;
  @override
  final String? requestId;

  const BbxOrderLimitFailure({
    required this.bound,
    required this.amount,
    required this.currency,
    this.code,
    this.apiCode,
    this.requestId,
    StackTrace? origin,
  }) : super(origin);

  @override
  String toString() =>
      'BbxOrderLimitFailure(bound: ${bound.name}, amount: $amount, '
      'currency: $currency${_requestIdSuffix(requestId)})';
}

/// The server refused a Confidential SEPA order because the recipient's
/// virtual payee is not active yet (`ERR_ORD_CSRCP400`).
final class BbxConfidentialSepaInactiveFailure extends BbxFailure {
  final int? code;
  final String? apiCode;
  @override
  final String? requestId;

  const BbxConfidentialSepaInactiveFailure({
    this.code,
    this.apiCode,
    this.requestId,
    StackTrace? origin,
  }) : super(origin);

  @override
  String toString() =>
      'BbxConfidentialSepaInactiveFailure(code: $code'
      '${_requestIdSuffix(requestId)})';
}

/// The phase of a request that ran out of time.
enum BbxTimeoutKind { connect, send, receive }

/// The request timed out in the [kind] phase.
final class BbxTimeoutFailure extends BbxFailure {
  final BbxTimeoutKind kind;

  const BbxTimeoutFailure(this.kind, {StackTrace? origin}) : super(origin);

  @override
  String toString() => 'BbxTimeoutFailure(kind: ${kind.name})';
}

/// The host could not be reached: DNS, refused or dropped connection.
final class BbxConnectionFailure extends BbxFailure {
  const BbxConnectionFailure({StackTrace? origin}) : super(origin);
}

/// The server's TLS certificate was rejected.
final class BbxBadCertificateFailure extends BbxFailure {
  const BbxBadCertificateFailure({StackTrace? origin}) : super(origin);
}

/// The request was cancelled.
final class BbxRequestCancelledFailure extends BbxFailure {
  const BbxRequestCancelledFailure({StackTrace? origin}) : super(origin);
}

/// The response could not be decoded before its transformation phase ended.
final class BbxTransformTimeoutFailure extends BbxFailure {
  const BbxTransformTimeoutFailure({StackTrace? origin}) : super(origin);
}

/// Any other transport failure.
final class BbxTransportFailure extends BbxFailure {
  const BbxTransportFailure({StackTrace? origin}) : super(origin);
}

/// A write failed after its request may have reached the server, so the
/// write may have happened: a send or receive timeout, a dropped connection,
/// a gateway error, a status below 400 other than 200, or a reply that could
/// not be read. Read the resource again before sending the write again.
///
/// [reason] names the failure and never quotes the request or the response.
final class BbxOutcomeUnknownFailure extends BbxFailure {
  final String reason;

  const BbxOutcomeUnknownFailure(this.reason, {StackTrace? origin})
    : super(origin);

  @override
  String toString() => 'BbxOutcomeUnknownFailure($reason)';
}

/// The response did not have the expected shape.
///
/// [reason] names the first invalid field, or the shape that was expected,
/// and never quotes the value.
final class BbxResponseFormatFailure extends BbxFailure {
  final String reason;

  const BbxResponseFormatFailure(this.reason, {StackTrace? origin})
    : super(origin);

  @override
  String toString() => 'BbxResponseFormatFailure($reason)';
}
