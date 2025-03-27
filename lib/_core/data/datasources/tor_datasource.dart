import 'package:recoverbull/recoverbull.dart';

class TorDatasource {
  final Tor _tor;

  TorDatasource._(this._tor);

  static Future<TorDatasource> init() async {
    await Tor.init();
    final instance = Tor.instance;

    return TorDatasource._(instance);
  }

  int get port => _tor.port;

  Future<bool> get isReady async {
    try {
      await _tor.isReady();
      return _tor.started && _tor.bootstrapped && _tor.port > 0;
    } catch (e) {
      return false;
    }
  }

  Future<void> start() async {
    if (!_tor.started) {
      await _tor.start();
    }
    await isReady;
  }

  Future<void> kill() async {
    await _tor.stop();
  }

  Tor get tor => _tor;
}
