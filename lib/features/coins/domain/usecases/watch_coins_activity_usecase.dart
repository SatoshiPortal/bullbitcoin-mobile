import 'package:sync/sync.dart' show WalletKey, WalletRevisionState;

final class WatchCoinsActivityUsecase {
  final Stream<WalletKey> _started;
  final Stream<WalletKey> _finished;
  final Stream<WalletRevisionState> _revisions;

  const WatchCoinsActivityUsecase(
    this._started,
    this._finished,
    this._revisions,
  );

  ({
    Stream<WalletKey> started,
    Stream<WalletKey> finished,
    Stream<WalletRevisionState> revisions,
  })
  execute(WalletKey key) => (
    started: _started.where((event) => event == key),
    finished: _finished.where((event) => event == key),
    revisions: _revisions.where((event) => event.stamp.key == key),
  );
}
