import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';

/// The signed-in account as the exchange screens see it. Every state that
/// holds account data names the session it belongs to, so nothing of one
/// account can be shown for another.
@immutable
sealed class ExchangeState {
  const ExchangeState();
}

/// No signed-in session.
final class ExchangeSignedOut extends ExchangeState {
  const ExchangeSignedOut();

  @override
  bool operator ==(Object other) => other is ExchangeSignedOut;

  @override
  int get hashCode => (ExchangeSignedOut).hashCode;
}

/// [session]'s account summary is being read for the first time.
final class ExchangeLoading extends ExchangeState {
  final ExchangeSession session;

  const ExchangeLoading(this.session);

  @override
  bool operator ==(Object other) =>
      other is ExchangeLoading && other.session == session;

  @override
  int get hashCode => Object.hash(ExchangeLoading, session);
}

/// [session]'s account summary could not be read; Retry reads it again.
final class ExchangeLoadFailed extends ExchangeState {
  final ExchangeSession session;
  final ExchangeFailure failure;

  const ExchangeLoadFailed(this.session, this.failure);

  @override
  bool operator ==(Object other) =>
      other is ExchangeLoadFailed &&
      other.session == session &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(ExchangeLoadFailed, session, failure);
}

/// [session]'s account is shown.
final class ExchangeLoaded extends ExchangeState {
  final ExchangeSession session;
  final UserSummary summary;
  final ExchangeAnnouncements announcements;
  final ExchangeRefresh refresh;
  final ExchangeDcaStop dcaStop;

  const ExchangeLoaded({
    required this.session,
    required this.summary,
    required this.announcements,
    required this.refresh,
    required this.dcaStop,
  });

  ExchangeLoaded copyWith({
    UserSummary? summary,
    ExchangeAnnouncements? announcements,
    ExchangeRefresh? refresh,
    ExchangeDcaStop? dcaStop,
  }) => ExchangeLoaded(
    session: session,
    summary: summary ?? this.summary,
    announcements: announcements ?? this.announcements,
    refresh: refresh ?? this.refresh,
    dcaStop: dcaStop ?? this.dcaStop,
  );

  /// Positive balances, or a zero balance in the account currency when
  /// there are none.
  List<UserBalance> get displayBalances {
    final positive = summary.balances.where((b) => b.amount > 0).toList();
    if (positive.isNotEmpty) return positive;
    final currency = summary.currency;
    return currency == null
        ? const []
        : [UserBalance(amount: 0, currencyCode: currency)];
  }

  @override
  bool operator ==(Object other) =>
      other is ExchangeLoaded &&
      other.session == session &&
      other.summary == summary &&
      other.announcements == announcements &&
      other.refresh == refresh &&
      other.dcaStop == dcaStop;

  @override
  int get hashCode =>
      Object.hash(session, summary, announcements, refresh, dcaStop);
}

/// The exchange announcements of a loaded account.
@immutable
sealed class ExchangeAnnouncements {
  const ExchangeAnnouncements();
}

final class AnnouncementsLoading extends ExchangeAnnouncements {
  const AnnouncementsLoading();

  @override
  bool operator ==(Object other) => other is AnnouncementsLoading;

  @override
  int get hashCode => (AnnouncementsLoading).hashCode;
}

final class AnnouncementsShown extends ExchangeAnnouncements {
  final List<Announcement> items;

  const AnnouncementsShown(this.items);

  @override
  bool operator ==(Object other) =>
      other is AnnouncementsShown && _sameList(other.items, items);

  @override
  int get hashCode => Object.hashAll(items);
}

/// The banner could not be read; nothing is shown for it.
final class AnnouncementsUnavailable extends ExchangeAnnouncements {
  final ExchangeFailure failure;

  const AnnouncementsUnavailable(this.failure);

  @override
  bool operator ==(Object other) =>
      other is AnnouncementsUnavailable && other.failure == failure;

  @override
  int get hashCode => Object.hash(AnnouncementsUnavailable, failure);
}

/// A refresh of a loaded account.
@immutable
sealed class ExchangeRefresh {
  const ExchangeRefresh();
}

final class RefreshIdle extends ExchangeRefresh {
  const RefreshIdle();

  @override
  bool operator ==(Object other) => other is RefreshIdle;

  @override
  int get hashCode => (RefreshIdle).hashCode;
}

final class Refreshing extends ExchangeRefresh {
  const Refreshing();

  @override
  bool operator ==(Object other) => other is Refreshing;

  @override
  int get hashCode => (Refreshing).hashCode;
}

/// The last refresh failed; the summary shown is older than that attempt.
final class RefreshFailed extends ExchangeRefresh {
  final ExchangeFailure failure;

  const RefreshFailed(this.failure);

  @override
  bool operator ==(Object other) =>
      other is RefreshFailed && other.failure == failure;

  @override
  int get hashCode => Object.hash(RefreshFailed, failure);
}

/// Turning the recurring buy off from the dashboard.
@immutable
sealed class ExchangeDcaStop {
  const ExchangeDcaStop();
}

final class DcaStopIdle extends ExchangeDcaStop {
  const DcaStopIdle();

  @override
  bool operator ==(Object other) => other is DcaStopIdle;

  @override
  int get hashCode => (DcaStopIdle).hashCode;
}

final class DcaStopping extends ExchangeDcaStop {
  const DcaStopping();

  @override
  bool operator ==(Object other) => other is DcaStopping;

  @override
  int get hashCode => (DcaStopping).hashCode;
}

final class DcaStopFailed extends ExchangeDcaStop {
  final ExchangeFailure failure;

  const DcaStopFailed(this.failure);

  @override
  bool operator ==(Object other) =>
      other is DcaStopFailed && other.failure == failure;

  @override
  int get hashCode => Object.hash(DcaStopFailed, failure);
}

bool _sameList<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

extension ExchangeStateSession on ExchangeState {
  /// The session whose account this state is about, if any.
  ExchangeSession? get session => switch (this) {
    ExchangeSignedOut() => null,
    ExchangeLoading(:final session) ||
    ExchangeLoadFailed(:final session) ||
    ExchangeLoaded(:final session) => session,
  };

  /// The loaded summary, only once it is shown.
  UserSummary? get loadedSummary => switch (this) {
    ExchangeLoaded(:final summary) => summary,
    ExchangeSignedOut() || ExchangeLoading() || ExchangeLoadFailed() => null,
  };
}
