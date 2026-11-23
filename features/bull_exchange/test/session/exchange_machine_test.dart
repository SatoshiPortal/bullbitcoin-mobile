import 'package:bull_exchange/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'a',
);
const _b = ExchangeSession(
  environment: ExchangeEnvironment.testnet,
  epoch: 2,
  sessionId: 'b',
);

const _summary = UserSummary(
  userNumber: 1,
  groups: [],
  profile: UserProfile(firstName: 'Sat', lastName: 'Oshi'),
  email: 'sat@example.com',
  balances: [],
  dca: UserDca(isActive: true),
  autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
);
const _newer = UserSummary(
  userNumber: 1,
  groups: [],
  profile: UserProfile(firstName: 'Sat', lastName: 'Oshi'),
  email: 'sat@example.com',
  balances: [],
  dca: UserDca(isActive: false),
  autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
);
const _failure = ExchangeNetworkFailure();
final _announcement = Announcement(
  title: 't',
  description: 'd',
  updatedAt: DateTime(2026),
);

ExchangeLoaded _loaded({
  ExchangeSession session = _a,
  UserSummary summary = _summary,
  ExchangeAnnouncements announcements = const AnnouncementsShown([]),
  ExchangeRefresh refresh = const RefreshIdle(),
  ExchangeDcaStop dcaStop = const DcaStopIdle(),
}) => ExchangeLoaded(
  session: session,
  summary: summary,
  announcements: announcements,
  refresh: refresh,
  dcaStop: dcaStop,
);

const _signedOut = ExchangeSignedOut();
const _loading = ExchangeLoading(_a);
const _loadFailed = ExchangeLoadFailed(_a, _failure);
final _idle = _loaded();
final _refreshing = _loaded(refresh: const Refreshing());
final _refreshFailed = _loaded(refresh: const RefreshFailed(_failure));
final _pendingBanner = _loaded(announcements: const AnnouncementsLoading());
final _stopping = _loaded(dcaStop: const DcaStopping());
final _stopFailed = _loaded(dcaStop: const DcaStopFailed(_failure));

/// One state of each shape the table distinguishes.
final _states = <String, ExchangeState>{
  'SignedOut': _signedOut,
  'Loading': _loading,
  'LoadFailed': _loadFailed,
  'Loaded idle': _idle,
  'Loaded refreshing': _refreshing,
  'Loaded refresh failed': _refreshFailed,
  'Loaded banner pending': _pendingBanner,
  'Loaded stopping DCA': _stopping,
  'Loaded DCA stop failed': _stopFailed,
};

/// Per event, the next state from each entry of [_states], in order.
final _table = <String, (ExchangeEvent, List<ExchangeState>)>{
  'signed in, same session': (
    const ExchangeAccessChanged(ExchangeAccessSignedIn(_a)),
    [
      _loading,
      _loading,
      _loadFailed,
      _idle,
      _refreshing,
      _refreshFailed,
      _pendingBanner,
      _stopping,
      _stopFailed,
    ],
  ),
  'signed in, another session (B1, B3)': (
    const ExchangeAccessChanged(ExchangeAccessSignedIn(_b)),
    List.filled(9, const ExchangeLoading(_b)),
  ),
  'signed out': (
    const ExchangeAccessChanged(
      ExchangeAccessSignedOut(ExchangeEnvironment.mainnet),
    ),
    List.filled(9, _signedOut),
  ),
  'expiring': (
    const ExchangeAccessChanged(ExchangeAccessExpiring(_a)),
    List.filled(9, _signedOut),
  ),
  'refresh requested (B10)': (
    const ExchangeRefreshRequested(),
    [
      _signedOut,
      _loading,
      _loading,
      _refreshing,
      _refreshing,
      _refreshing,
      _loaded(
        announcements: const AnnouncementsLoading(),
        refresh: const Refreshing(),
      ),
      _loaded(dcaStop: const DcaStopping(), refresh: const Refreshing()),
      _loaded(
        dcaStop: const DcaStopFailed(_failure),
        refresh: const Refreshing(),
      ),
    ],
  ),
  'summary of this session': (
    const ExchangeSummaryLoaded(_a, _newer),
    [
      _signedOut,
      _loaded(summary: _newer, announcements: const AnnouncementsLoading()),
      _loadFailed,
      _idle,
      _loaded(summary: _newer),
      _refreshFailed,
      _pendingBanner,
      _stopping,
      _stopFailed,
    ],
  ),
  'summary of another session': (
    const ExchangeSummaryLoaded(_b, _newer),
    [
      _signedOut,
      _loading,
      _loadFailed,
      _idle,
      _refreshing,
      _refreshFailed,
      _pendingBanner,
      _stopping,
      _stopFailed,
    ],
  ),
  'summary failure of this session': (
    const ExchangeSummaryFailed(_a, ExchangeAccountUnavailableFailure()),
    [
      _signedOut,
      const ExchangeLoadFailed(_a, ExchangeAccountUnavailableFailure()),
      _loadFailed,
      _idle,
      _loaded(
        refresh: const RefreshFailed(ExchangeAccountUnavailableFailure()),
      ),
      _refreshFailed,
      _pendingBanner,
      _stopping,
      _stopFailed,
    ],
  ),
  'summary failure of another session': (
    const ExchangeSummaryFailed(_b, _failure),
    [
      _signedOut,
      _loading,
      _loadFailed,
      _idle,
      _refreshing,
      _refreshFailed,
      _pendingBanner,
      _stopping,
      _stopFailed,
    ],
  ),
  'announcements of this session': (
    ExchangeAnnouncementsLoaded(_a, [_announcement]),
    [
      _signedOut,
      _loading,
      _loadFailed,
      _idle,
      _refreshing,
      _refreshFailed,
      _loaded(announcements: AnnouncementsShown([_announcement])),
      _stopping,
      _stopFailed,
    ],
  ),
  'announcements of another session': (
    const ExchangeAnnouncementsLoaded(_b, []),
    [
      _signedOut,
      _loading,
      _loadFailed,
      _idle,
      _refreshing,
      _refreshFailed,
      _pendingBanner,
      _stopping,
      _stopFailed,
    ],
  ),
  'announcements failure of this session': (
    const ExchangeAnnouncementsFailed(_a, _failure),
    [
      _signedOut,
      _loading,
      _loadFailed,
      _idle,
      _refreshing,
      _refreshFailed,
      _loaded(announcements: const AnnouncementsUnavailable(_failure)),
      _stopping,
      _stopFailed,
    ],
  ),
  'announcements failure of another session': (
    const ExchangeAnnouncementsFailed(_b, _failure),
    [
      _signedOut,
      _loading,
      _loadFailed,
      _idle,
      _refreshing,
      _refreshFailed,
      _pendingBanner,
      _stopping,
      _stopFailed,
    ],
  ),
  'stop DCA requested (B17 stopDca)': (
    const ExchangeStopDcaRequested(),
    [
      _signedOut,
      _loading,
      _loadFailed,
      _stopping,
      _loaded(refresh: const Refreshing(), dcaStop: const DcaStopping()),
      _loaded(
        refresh: const RefreshFailed(_failure),
        dcaStop: const DcaStopping(),
      ),
      _loaded(
        announcements: const AnnouncementsLoading(),
        dcaStop: const DcaStopping(),
      ),
      _stopping,
      _stopping,
    ],
  ),
  'DCA stopped for this session': (
    const ExchangeDcaStopped(_a),
    [
      _signedOut,
      _loading,
      _loadFailed,
      _idle,
      _refreshing,
      _refreshFailed,
      _pendingBanner,
      _refreshing,
      _stopFailed,
    ],
  ),
  'DCA stopped for another session': (
    const ExchangeDcaStopped(_b),
    [
      _signedOut,
      _loading,
      _loadFailed,
      _idle,
      _refreshing,
      _refreshFailed,
      _pendingBanner,
      _stopping,
      _stopFailed,
    ],
  ),
  'DCA stop failed for this session': (
    const ExchangeDcaStopFailed(_a, ExchangeAccountUnavailableFailure()),
    [
      _signedOut,
      _loading,
      _loadFailed,
      _idle,
      _refreshing,
      _refreshFailed,
      _pendingBanner,
      _loaded(
        dcaStop: const DcaStopFailed(ExchangeAccountUnavailableFailure()),
      ),
      _stopFailed,
    ],
  ),
  'DCA stop failed for another session': (
    const ExchangeDcaStopFailed(_b, _failure),
    [
      _signedOut,
      _loading,
      _loadFailed,
      _idle,
      _refreshing,
      _refreshFailed,
      _pendingBanner,
      _stopping,
      _stopFailed,
    ],
  ),
};

void main() {
  test('every row names every state', () {
    for (final (_, next) in _table.values) {
      expect(next, hasLength(_states.length));
    }
  });

  final names = _states.keys.toList();
  for (final MapEntry(key: row, value: (event, next)) in _table.entries) {
    for (var i = 0; i < names.length; i++) {
      test('${names[i]} + $row', () {
        expect(transitionExchange(_states[names[i]]!, event), next[i]);
      });
    }
  }

  test('signed out from signed out stays signed out', () {
    expect(
      transitionExchange(
        _signedOut,
        const ExchangeAccessChanged(ExchangeAccessDisabled()),
      ),
      _signedOut,
    );
  });

  test('every state is reachable from signed out', () {
    final events = [for (final (event, _) in _table.values) event];
    final reached = <Type>{};
    var frontier = <ExchangeState>[_signedOut];
    final seen = <ExchangeState>{_signedOut};
    while (frontier.isNotEmpty) {
      final next = <ExchangeState>[];
      for (final state in frontier) {
        reached.add(state.runtimeType);
        for (final event in events) {
          final target = transitionExchange(state, event);
          if (seen.add(target)) next.add(target);
        }
      }
      frontier = next;
    }
    expect(reached, {
      ExchangeSignedOut,
      ExchangeLoading,
      ExchangeLoadFailed,
      ExchangeLoaded,
    });
    expect(seen.whereType<ExchangeLoaded>().map((s) => s.refresh.runtimeType), {
      RefreshIdle,
      Refreshing,
      RefreshFailed,
    });
    expect(seen.whereType<ExchangeLoaded>().map((s) => s.dcaStop.runtimeType), {
      DcaStopIdle,
      DcaStopping,
      DcaStopFailed,
    });
  });
}
