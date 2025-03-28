import 'package:recoverbull/recoverbull.dart';

abstract class TorDatasource {
  /// Get the Tor client instance
  Future<void> start();

  /// Check if Tor is ready (bootstrapped and has valid port)
  Future<bool> get isReady;

  bool get started;
  Tor get tor;

  /// Get the port number Tor is using
  int get port;

  /// Kill the Tor client
  Future<void> kill();
}

class TorDatasourceImpl implements TorDatasource {
  final Tor _tor;

  TorDatasourceImpl._(this._tor);

  static Future<TorDatasourceImpl> init() async {
    if (!Tor.instance.enabled) await Tor.init();
    return TorDatasourceImpl._(Tor.instance);
  }

  @override
  int get port => _tor.port;
  @override
  bool get started => _tor.started;
  @override
  Future<bool> get isReady async {
    try {
      await _tor.isReady();
      return _tor.bootstrapped && _tor.port > 0;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> start() async {
    print("Is Tor started: ${_tor.started}");
    if (!_tor.started) {
      await _tor.start();
    }
  }

  @override
  Future<void> kill() async {
    await _tor.stop();
  }

  @override
  Tor get tor => _tor;
}
