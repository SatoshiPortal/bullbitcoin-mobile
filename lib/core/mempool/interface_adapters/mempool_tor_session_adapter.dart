import 'package:bb_mobile/core/mempool/domain/ports/mempool_tor_session_port.dart';
import 'package:bull_tor/tor.dart';

final class MempoolTorSessionAdapter implements MempoolTorSessionPort {
  final Tor Function() _tor;

  const MempoolTorSessionAdapter(this._tor);

  @override
  Future<MempoolTorRoute?> open({required String serverUrl}) async {
    final address = serverUrl.contains('://')
        ? serverUrl
        : 'https://$serverUrl';
    final host = Uri.parse(address).host.toLowerCase();
    if (!host.endsWith('.onion')) return null;

    final session = await _tor().embedded.sessions.open();
    return MempoolTorRoute(session.endpoint, session.close);
  }
}
