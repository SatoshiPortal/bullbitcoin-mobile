import 'package:electrum/electrum.dart';
import 'package:network/src/electrum_settings/presentation/electrum_server_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

bool _isEncrypted(String url) => ElectrumServerViewModel(
  url: url,
  network: ElectrumServerNetwork.bitcoinMainnet,
  status: ElectrumServerStatus.unknown,
  priority: 0,
).isEncrypted;

void main() {
  test('ssl and scheme-less servers are encrypted', () {
    expect(_isEncrypted('ssl://electrum.example.com:50002'), isTrue);
    expect(_isEncrypted('electrum.example.com:50002'), isTrue);
  });

  test('a clearnet tcp server is not encrypted', () {
    expect(_isEncrypted('tcp://electrum.example.com:50001'), isFalse);
  });

  test('a tcp onion server is encrypted by Tor', () {
    expect(_isEncrypted('tcp://abcdefghijklmnop.onion:50001'), isTrue);
  });
}
