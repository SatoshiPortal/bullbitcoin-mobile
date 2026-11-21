import 'package:bull_tor/tor.dart';

class WatchTorSettingsUsecase {
  final EmbeddedTor _embeddedTor;

  const WatchTorSettingsUsecase(this._embeddedTor);

  /// The screen should immediately reflect the running client when mounted.
  Stream<TorConnectionState> execute() => _embeddedTor.states;
}
