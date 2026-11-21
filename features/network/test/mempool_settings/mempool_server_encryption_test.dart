import 'package:mempool/mempool.dart';
import 'package:network/src/mempool_settings/presentation/mempool_server_encryption.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

bool _isEncrypted(String url, {required bool enableSsl}) =>
    MempoolServer.tryCreateCustom(
      url: url,
      network: BitcoinNetwork.mainnet,
      enableSsl: enableSsl,
    ).fold(
      (server) => server.isEncrypted,
      (failure) => throw StateError('Invalid server fixture: $failure'),
    );

void main() {
  test('https servers are encrypted', () {
    expect(_isEncrypted('mempool.example.com', enableSsl: true), isTrue);
  });

  test('a clearnet http server is not encrypted', () {
    expect(_isEncrypted('mempool.example.com:8080', enableSsl: false), isFalse);
  });

  test('an http onion server is encrypted by Tor', () {
    expect(
      _isEncrypted('abcdefghijklmnop.onion:3000', enableSsl: false),
      isTrue,
    );
  });
}
