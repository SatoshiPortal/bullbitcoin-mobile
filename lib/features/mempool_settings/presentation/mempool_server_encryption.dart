import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_url.dart';
import 'package:bb_mobile/core/mempool/application/dtos/mempool_server_dto.dart';

extension MempoolServerEncryption on MempoolServerDto {
  /// Whether the connection is encrypted end to end: HTTPS, or an onion
  /// service (Tor encrypts it even over plain HTTP).
  bool get isEncrypted {
    if (enableSsl) return true;
    final host = Uri.tryParse('http://$url')?.host;
    return host != null && ElectrumServerUrl.isOnionHost(host);
  }
}
