import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

@immutable
sealed class SupportUnreadEvent {
  const SupportUnreadEvent();
}

final class UnreadAccessChanged extends SupportUnreadEvent {
  final ExchangeAccess access;

  const UnreadAccessChanged(this.access);
}

/// A new support message was pushed, the app came back, or the user
/// refreshed: the count may have changed.
final class UnreadRecheckRequested extends SupportUnreadEvent {
  const UnreadRecheckRequested();
}

/// The support chat showed its newest messages to the user.
final class UnreadChatShown extends SupportUnreadEvent {
  const UnreadChatShown();
}

final class UnreadCountAnswered extends SupportUnreadEvent {
  final ExchangeSession session;
  final int attempt;
  final Result<int, ExchangeReadFailure> read;

  const UnreadCountAnswered(this.session, this.attempt, this.read);
}

final class UnreadMarkAnswered extends SupportUnreadEvent {
  final ExchangeSession session;
  final int attempt;
  final Result<void, ExchangeWriteFailure> write;

  const UnreadMarkAnswered(this.session, this.attempt, this.write);
}
