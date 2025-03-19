import 'package:recoverbull/recoverbull.dart';

abstract class TorDatasource {
  /// Get the Tor client instance
  Future<void> start();

  /// Check if Tor is ready (bootstrapped and has valid port)
  Future<bool> get isReady;
  Tor get tor;

  /// Get the port number Tor is using
  int get port;

  /// Kill the Tor client
  Future<void> kill();
}

class TorDatasourceImpl implements TorDatasource {
  final Tor _tor;
  bool _isStarted = false;

  TorDatasourceImpl._(this._tor);

  static Future<TorDatasourceImpl> init() async {
    await Tor.init();
    final instance = Tor.instance;

    return TorDatasourceImpl._(instance);
  }

  @override
  int get port => _tor.port;

  @override
  Future<bool> get isReady async {
    try {
      await _tor.isReady();
      return _isStarted && _tor.bootstrapped && _tor.port > 0;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> start() async {
    if (!_isStarted) {
      await _tor.start();
      _isStarted = true;
    }
    await isReady;
  }

  @override
  Future<void> kill() async {
    await _tor.stop();
    _isStarted = false;
  }

  @override
  Tor get tor => _tor;
}
