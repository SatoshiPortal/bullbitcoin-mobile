import 'package:bb_mobile/core/mempool/application/dtos/mempool_server_dto.dart';
import 'package:bb_mobile/features/mempool_settings/presentation/mempool_server_encryption.dart';
import 'package:flutter_test/flutter_test.dart';

bool _isEncrypted(String url, {required bool enableSsl}) => MempoolServerDto(
  url: url,
  isCustom: true,
  isTestnet: false,
  isLiquid: false,
  enableSsl: enableSsl,
).isEncrypted;

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
