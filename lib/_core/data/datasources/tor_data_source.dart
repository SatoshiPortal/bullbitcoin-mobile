import 'package:recoverbull/recoverbull.dart';

abstract class TorDataSource {
  /// Get the Tor client instance
  Tor getTorClient();

  /// Check if Tor is ready (bootstrapped and has valid port)
  Future<bool> get isReady;

  /// Get the port number Tor is using
  int get port;

  /// Kill the Tor client
  Future<void> kill();
}

class TorDataSourceImpl implements TorDataSource {
  final Tor _tor;

  TorDataSourceImpl._(this._tor);

  static Future<TorDataSourceImpl> init() async {
    await Tor.init();
    final instance = Tor.instance;
    // Start Tor service
    await instance.start();
    // Wait for Tor to be ready
    await instance.isReady();

    // // Return initialized data source with Tor instance
    return TorDataSourceImpl._(instance);
  }

  @override
  int get port => _tor.port;

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
  Tor getTorClient() => _tor;

  @override
  Future<void> kill() async {
    await _tor.stop();
  }
}
