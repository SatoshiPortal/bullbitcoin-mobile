part of 'exchange_failure.dart';

/// Why the exchange refused a call: codes only, never the server's text,
/// which can quote account details.
final class ExchangeRefusal {
  final int? rpcCode;
  final String? apiCode;
  final int? httpStatus;

  /// Set when the exchange refused an order for its amount: the bound it
  /// broke, in the currency it names.
  final ExchangeOrderLimit? orderLimit;

  /// The exchange refused a Confidential SEPA payout because the recipient's
  /// virtual payee is not active.
  final bool payeeInactive;

  /// The request fields the exchange's validation refused: each field path
  /// to its `ERR_VALIDATION_` code. Never a value.
  final Map<String, String> fieldErrors;

  const ExchangeRefusal({
    this.rpcCode,
    this.apiCode,
    this.httpStatus,
    this.orderLimit,
    this.payeeInactive = false,
    this.fieldErrors = const {},
  });

  @override
  bool operator ==(Object other) =>
      other is ExchangeRefusal &&
      other.rpcCode == rpcCode &&
      other.apiCode == apiCode &&
      other.httpStatus == httpStatus &&
      other.orderLimit == orderLimit &&
      other.payeeInactive == payeeInactive &&
      other.fieldErrors.length == fieldErrors.length &&
      fieldErrors.entries.every((e) => other.fieldErrors[e.key] == e.value);

  @override
  int get hashCode => Object.hash(
    rpcCode,
    apiCode,
    httpStatus,
    orderLimit,
    payeeInactive,
    Object.hashAllUnordered(
      fieldErrors.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() =>
      'ExchangeRefusal(rpcCode: $rpcCode, apiCode: $apiCode, '
      'httpStatus: $httpStatus, orderLimit: $orderLimit, '
      'payeeInactive: $payeeInactive'
      '${fieldErrors.isEmpty ? '' : ', fields: ${fieldErrors.keys.toList()}'})';
}

/// The order amount bound the exchange refused an order for.
final class ExchangeOrderLimit {
  final ExchangeOrderAmountBound bound;
  final double amount;
  final String currency;

  const ExchangeOrderLimit(this.bound, this.amount, this.currency);

  @override
  bool operator ==(Object other) =>
      other is ExchangeOrderLimit &&
      other.bound == bound &&
      other.amount == amount &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(bound, amount, currency);

  @override
  String toString() => 'ExchangeOrderLimit(${bound.name}, $amount $currency)';
}

/// Why a call never left the app.
enum ExchangeNotSentReason {
  /// No API key is stored.
  signedOut,

  /// The stored API key could not be read.
  credentialUnavailable,

  /// The session changed (environment or sign-in) before the request was
  /// sent.
  sessionChanged,

  /// The connection failed before the request was sent, or the exchange is
  /// not available in this environment.
  unreachable,
}

/// Why a read has no usable session.
enum ExchangeSessionRejection {
  /// The server answered HTTP 401 to the request's key.
  server,

  /// No API key is stored.
  signedOut,

  /// The stored API key could not be read.
  credentialUnavailable,

  /// The session the read was started for ended before it was answered
  /// (sign-out, another sign-in, or an environment switch).
  sessionChanged,
}

/// What reading one resource can fail with. A read answers
/// `Result<T, ExchangeReadFailure>`: [Ok] holds the value, and nothing else
/// is ever read as one.
sealed class ExchangeReadFailure implements ExchangeFailure {}

/// What a write (create, confirm, accelerate, save) can fail with. A write
/// answers `Result<T, ExchangeWriteFailure>`.
///
/// [ExchangeWriteOutcomeUnknownFailure] means the write may have happened:
/// read the resource again before offering the write again.
sealed class ExchangeWriteFailure implements ExchangeFailure {}

/// What reading one page of a list can fail with. A failure is never an
/// empty page.
sealed class ExchangeListFailure implements ExchangeFailure {}

/// The server answered that there is no such resource.
final class ExchangeMissingFailure extends ExchangeFailure
    implements ExchangeReadFailure {
  const ExchangeMissingFailure();
}

/// No usable answer: the network failed ([isNetwork]) or the server failed.
/// [reason] is log-safe.
final class ExchangeUnreachableFailure extends ExchangeFailure
    implements ExchangeReadFailure, ExchangeListFailure {
  final bool isNetwork;
  final String reason;

  const ExchangeUnreachableFailure(this.reason, {required this.isNetwork})
    : super(reason);
}

/// The server answered, but the answer could not be read. [reason] is
/// log-safe.
final class ExchangeMalformedFailure extends ExchangeFailure
    implements ExchangeReadFailure {
  final String reason;

  const ExchangeMalformedFailure(this.reason) : super(reason);
}

/// The call has no usable session: the server answered HTTP 401 to its key
/// ([ExchangeSessionRejection.server]), or the session it was started for is
/// gone ([why]). Only a server rejection may expire a session automatically.
final class ExchangeSessionRejectedFailure extends ExchangeFailure
    implements ExchangeReadFailure, ExchangeWriteFailure, ExchangeListFailure {
  final ExchangeSessionRejection why;

  const ExchangeSessionRejectedFailure(this.why, [super.logMessage]);
}

/// The exchange refused the write for [reason]: it did not happen.
final class ExchangeWriteRefusedFailure extends ExchangeFailure
    implements ExchangeWriteFailure {
  final ExchangeRefusal reason;

  const ExchangeWriteRefusedFailure(this.reason);
}

/// The request may have reached the server, but its answer is lost or could
/// not be read. [reason] is log-safe.
final class ExchangeWriteOutcomeUnknownFailure extends ExchangeFailure
    implements ExchangeWriteFailure {
  final String reason;

  const ExchangeWriteOutcomeUnknownFailure(this.reason) : super(reason);
}

/// The write never left the app, for [reason].
final class ExchangeWriteNotSentFailure extends ExchangeFailure
    implements ExchangeWriteFailure {
  final ExchangeNotSentReason reason;

  const ExchangeWriteNotSentFailure(this.reason);
}
