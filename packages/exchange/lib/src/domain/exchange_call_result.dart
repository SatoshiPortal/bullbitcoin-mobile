/// The closed sets every exchange call ends in. Repositories turn each server
/// or transport answer into exactly one of these; nothing else reaches a flow.
library;

import 'exchange_failure.dart';

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
