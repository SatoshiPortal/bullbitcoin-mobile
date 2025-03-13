import 'package:recoverbull/recoverbull.dart';

abstract class TorDataSource {
  Tor getTorClient();
  void kill();
}

class TorDataSourceImpl implements TorDataSource {
  final Tor _tor;

  TorDataSourceImpl(this._tor);

  static Future<TorDataSource> init() async {
    await Tor.init();
    await Tor.instance.start();
    await Tor.instance.isReady();
    return TorDataSourceImpl(Tor.instance);
  }

  @override
  Tor getTorClient() => _tor;

  @override
  void kill() => _tor.stop();
}
