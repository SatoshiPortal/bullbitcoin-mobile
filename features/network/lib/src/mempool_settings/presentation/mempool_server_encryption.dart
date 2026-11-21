import 'package:electrum/electrum.dart';
import 'package:mempool/mempool.dart';

extension MempoolServerEncryption on MempoolServerDto {
  /// Whether the connection is encrypted end to end: HTTPS, or an onion
  /// service (Tor encrypts it even over plain HTTP).
  bool get isEncrypted {
    if (enableSsl) return true;
    final host = Uri.tryParse('http://$url')?.host;
    return host != null && ElectrumServerUrl.isOnionHost(host);
  }
}
