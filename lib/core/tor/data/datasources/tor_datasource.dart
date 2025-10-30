import 'package:recoverbull/recoverbull.dart';

class TorDatasource {
  final Tor _tor;

  TorDatasource._(this._tor);

  static Future<TorDatasource> init() async {
    // enable: false
    // ensures that the Tor service is not started automatically
    await Tor.init(enabled: false);
    return TorDatasource._(Tor.instance);
  }

  int get port => _tor.port;
  bool get isEnabled => _tor.enabled;

  Future<void> enable() async {
    if (!_tor.enabled) {
      await _tor.enable();
      await waitUntilReady();
    }
  }

  void disable() => _tor.disable();

  Future<void> kill() async {
    disable();
    await _tor.stop();
  }

  Future<void> waitUntilReady() async {
    await _tor.isReady();
  }

  Future<bool> get isReady async {
    try {
      await waitUntilReady();
      return _tor.bootstrapped && _tor.port > 0;
    } catch (e) {
      return false;
    }
  }
}
