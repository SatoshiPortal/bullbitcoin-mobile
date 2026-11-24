/// The closed sets every exchange call ends in. Repositories turn each server
/// or transport answer into exactly one of these; nothing else reaches a flow.
library;

/// Why the exchange refused a call: codes only, never the server's text,
/// which can quote account details.
final class ExchangeRefusal {
  final int? rpcCode;
  final String? apiCode;
  final int? httpStatus;

  const ExchangeRefusal({this.rpcCode, this.apiCode, this.httpStatus});

  @override
  bool operator ==(Object other) =>
      other is ExchangeRefusal &&
      other.rpcCode == rpcCode &&
      other.apiCode == apiCode &&
      other.httpStatus == httpStatus;

  @override
  int get hashCode => Object.hash(rpcCode, apiCode, httpStatus);

  @override
  String toString() =>
      'ExchangeRefusal(rpcCode: $rpcCode, apiCode: $apiCode, '
      'httpStatus: $httpStatus)';
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

/// The result of a write (create, confirm, accelerate, save).
///
/// [WriteOutcomeUnknown] means the write may have happened: read the resource
/// again before offering the write again.
sealed class ExchangeWrite<T> {
  const ExchangeWrite();
}

final class WriteDone<T> extends ExchangeWrite<T> {
  final T value;

  const WriteDone(this.value);
}

final class WriteRefused<T> extends ExchangeWrite<T> {
  final ExchangeRefusal reason;

  const WriteRefused(this.reason);
}

/// The request may have reached the server, but its answer is lost or could
/// not be read. [reason] is log-safe.
final class WriteOutcomeUnknown<T> extends ExchangeWrite<T> {
  final String reason;

  const WriteOutcomeUnknown(this.reason);
}

final class WriteNotSent<T> extends ExchangeWrite<T> {
  final ExchangeNotSentReason reason;

  const WriteNotSent(this.reason);
}

/// The server answered HTTP 401: the session's key is no longer valid.
final class WriteSessionRejected<T> extends ExchangeWrite<T> {
  const WriteSessionRejected();
}

/// The result of reading one resource.
sealed class ExchangeRead<T> {
  const ExchangeRead();
}

final class ReadGot<T> extends ExchangeRead<T> {
  final T value;

  const ReadGot(this.value);
}

/// The server answered that there is no such resource.
final class ReadMissing<T> extends ExchangeRead<T> {
  const ReadMissing();
}

/// No usable answer: the network failed ([isNetwork]) or the server failed.
/// [reason] is log-safe.
final class ReadUnreachable<T> extends ExchangeRead<T> {
  final bool isNetwork;
  final String reason;

  const ReadUnreachable(this.reason, {required this.isNetwork});
}

final class ReadSessionRejected<T> extends ExchangeRead<T> {
  final ExchangeSessionRejection why;

  const ReadSessionRejected(this.why);
}

/// The server answered, but the answer could not be read. [reason] is
/// log-safe.
final class ReadMalformed<T> extends ExchangeRead<T> {
  final String reason;

  const ReadMalformed(this.reason);
}

/// The result of reading one page of a list. A failure is never an empty
/// page.
sealed class ExchangeList<T> {
  const ExchangeList();
}

/// [next] is the next page number, or null on the last page.
final class ListPage<T> extends ExchangeList<T> {
  final List<T> items;
  final int? next;

  const ListPage(this.items, {this.next});
}

final class ListUnreachable<T> extends ExchangeList<T> {
  final bool isNetwork;
  final String reason;

  const ListUnreachable(this.reason, {required this.isNetwork});
}

final class ListSessionRejected<T> extends ExchangeList<T> {
  final ExchangeSessionRejection why;

  const ListSessionRejected(this.why);
}
